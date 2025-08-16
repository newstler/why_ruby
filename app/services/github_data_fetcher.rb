class GithubDataFetcher
  attr_reader :user, :auth_data, :api_token

  # Can be initialized with either OAuth auth_data (for sign-in) or without it (for scheduled updates)
  def initialize(user, auth_data = nil)
    @user = user
    @auth_data = auth_data
    @api_token = auth_data&.credentials&.token || Rails.application.credentials.dig(:github, :api_token)
  end

  def fetch_and_update!
    update_basic_profile
    fetch_and_store_repositories
    user.update!(github_data_updated_at: Time.current)
  end

  private

  def update_basic_profile
    if auth_data&.extra&.raw_info
      # Use OAuth data if available (during sign-in)
      update_from_oauth_data
    else
      # Fetch from GitHub API (for scheduled updates)
      update_from_api
    end
  end

  def update_from_oauth_data
    raw_info = auth_data.extra.raw_info

    user.update!(
      name: raw_info.name,
      bio: raw_info.bio,
      company: raw_info.company,
      website: raw_info.blog.presence,
      twitter: raw_info.twitter_username.presence,
      location: raw_info.location,
      avatar_url: auth_data.info.image
    )
  end

  def update_from_api
    require "net/http"
    require "json"

    return unless user.username.present?

    uri = URI("https://api.github.com/users/#{user.username}")
    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/vnd.github.v3+json"
    request["Authorization"] = "Bearer #{api_token}" if api_token.present?

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.code == "200"
      data = JSON.parse(response.body)

      user.update!(
        name: data["name"],
        bio: data["bio"],
        company: data["company"],
        website: data["blog"],
        twitter: data["twitter_username"],
        location: data["location"],
        avatar_url: data["avatar_url"]
      )
    else
      Rails.logger.error "Failed to fetch GitHub profile for #{user.username}: #{response.code} - #{response.message}"
      raise "GitHub API error: #{response.code}" unless response.code == "404"
    end
  end

  def fetch_and_store_repositories
    # Get username from auth_data if available, otherwise from user
    github_username = auth_data&.info&.nickname || user.username

    return unless github_username.present?

    # Store repos as JSON in the github_repos field
    repos = fetch_ruby_repositories(github_username)
    user.update!(github_repos: repos.to_json) if repos.present?
  rescue => e
    Rails.logger.error "Failed to fetch GitHub repositories for #{github_username}: #{e.message}"
  end

  def fetch_ruby_repositories(username)
    require "net/http"
    require "json"

    uri = URI("https://api.github.com/users/#{username}/repos?per_page=100&sort=pushed")

    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/vnd.github.v3+json"
    request["Authorization"] = "Bearer #{api_token}" if api_token.present?

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.code == "200"
      repos = JSON.parse(response.body)

      # Filter for Ruby repositories, excluding forks
      ruby_repos = repos.select do |repo|
        # Skip forked repositories - we only want original work
        next if repo["fork"]

        # Check if it's a Ruby-related repository
        repo["language"] == "Ruby" ||
        repo["description"]&.downcase&.include?("ruby") ||
        repo["name"]&.downcase&.include?("ruby") ||
        repo["name"]&.downcase&.include?("rails")
      end.map do |repo|
        # Only store fields we actually display on the user's page
        {
          name: repo["name"],
          description: repo["description"],
          stars: repo["stargazers_count"],
          url: repo["html_url"],
          forks_count: repo["forks_count"],
          size: repo["size"], # Size in KB
          topics: repo["topics"] || [],
          pushed_at: repo["pushed_at"]
        }
      end.sort_by { |r| -r[:stars] } # Sort by stars descending

      ruby_repos
    else
      Rails.logger.error "GitHub API returned #{response.code} for #{username}: #{response.body}"
      []
    end
  end
end
