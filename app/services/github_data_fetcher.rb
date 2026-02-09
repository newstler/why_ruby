class GithubDataFetcher
  GRAPHQL_ENDPOINT = "https://api.github.com/graphql"

  attr_reader :user, :auth_data, :api_token

  # Can be initialized with either OAuth auth_data (for sign-in) or without it (for scheduled updates)
  def initialize(user, auth_data = nil)
    @user = user
    @auth_data = auth_data
    @api_token = auth_data&.credentials&.token || Rails.application.credentials.dig(:github, :api_token)
  end

  # === Class Methods for Batch GraphQL Fetching ===

  # Main batch method - fetches and updates multiple users in a single GraphQL request
  # Automatically splits batch on transient errors (502/503/504)
  def self.batch_fetch_and_update!(users, api_token: nil)
    api_token ||= Rails.application.credentials.dig(:github, :api_token)
    return { updated: 0, failed: users.size, errors: [ "No API token configured" ] } unless api_token.present?

    users_with_usernames = users.select { |u| u.username.present? }
    return { updated: 0, failed: 0, errors: [] } if users_with_usernames.empty?

    query = build_batch_query(users_with_usernames)
    response = graphql_request(query, api_token, retries: 2)

    # On transient errors, split batch in half and retry recursively
    if response[:errors].present? && response[:data].nil?
      error_msg = response[:errors].first.to_s
      if error_msg.match?(/50[234]/) && users_with_usernames.size > 1
        Rails.logger.warn "Batch of #{users_with_usernames.size} failed with #{error_msg}, splitting in half..."
        mid = users_with_usernames.size / 2
        first_half = batch_fetch_and_update!(users_with_usernames[0...mid], api_token: api_token)
        sleep(1) # Brief pause between split batches
        second_half = batch_fetch_and_update!(users_with_usernames[mid..], api_token: api_token)

        return {
          updated: first_half[:updated] + second_half[:updated],
          failed: first_half[:failed] + second_half[:failed],
          errors: first_half[:errors] + second_half[:errors]
        }
      end

      return { updated: 0, failed: users_with_usernames.size, errors: response[:errors] }
    end

    updated = 0
    failed = 0
    errors = []

    users_with_usernames.each_with_index do |user, index|
      user_key = :"user_#{index}"
      repos_key = :"repos_#{index}"
      user_data = response.dig(:data, user_key)
      repos_data = response.dig(:data, repos_key, :nodes)

      if user_data.nil?
        failed += 1
        errors << "User #{user.username} not found on GitHub"
        next
      end

      begin
        update_user_from_graphql(user, user_data, repos_data || [])
        updated += 1
      rescue => e
        failed += 1
        errors << "Failed to update #{user.username}: #{e.message}"
        Rails.logger.error "GraphQL batch update error for #{user.username}: #{e.message}"
      end
    end

    { updated: updated, failed: failed, errors: errors }
  end

  # Execute a GraphQL request with retry for transient errors
  def self.graphql_request(query, api_token, retries: 3)
    require "net/http"
    require "json"

    uri = URI(GRAPHQL_ENDPOINT)

    retries.times do |attempt|
      begin
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Bearer #{api_token}"
        request.body = { query: query }.to_json

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        if response.code == "200"
          return JSON.parse(response.body, symbolize_names: true)
        elsif %w[502 503 504].include?(response.code) && attempt < retries - 1
          sleep_time = 2 ** (attempt + 1) # Exponential backoff: 2, 4, 8 seconds
          Rails.logger.warn "GraphQL request got #{response.code}, retrying in #{sleep_time}s (attempt #{attempt + 1}/#{retries})"
          sleep(sleep_time)
          next
        else
          Rails.logger.error "GraphQL request failed: #{response.code} - #{response.body}"
          return { errors: [ "HTTP #{response.code}: #{response.message}" ] }
        end
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        if attempt < retries - 1
          sleep_time = 2 ** (attempt + 1)
          Rails.logger.warn "GraphQL request timed out, retrying in #{sleep_time}s (attempt #{attempt + 1}/#{retries})"
          sleep(sleep_time)
          next
        else
          Rails.logger.error "GraphQL request timed out after #{retries} attempts: #{e.message}"
          return { errors: [ "Request timed out: #{e.message}" ] }
        end
      end
    end
  end

  # Build a batched GraphQL query for multiple users using aliases
  # Uses search query to filter by language:Ruby server-side
  def self.build_batch_query(users)
    user_queries = users.each_with_index.map do |user, index|
      <<~GRAPHQL
        user_#{index}: user(login: "#{user.username}") {
          login
          email
          name
          bio
          company
          websiteUrl
          twitterUsername
          location
          avatarUrl
        }
        repos_#{index}: search(query: "user:#{user.username} language:Ruby fork:false archived:false sort:updated", type: REPOSITORY, first: 100) {
          nodes {
            ... on Repository {
              name
              description
              stargazerCount
              url
              forks {
                totalCount
              }
              diskUsage
              pushedAt
              repositoryTopics(first: 10) {
                nodes {
                  topic {
                    name
                  }
                }
              }
            }
          }
        }
      GRAPHQL
    end.join("\n")

    "query { #{user_queries} }"
  end

  # Update a user from GraphQL response data
  def self.update_user_from_graphql(user, profile_data, repos_data)
    # Update profile fields
    user.update!(
      username: profile_data[:login],
      email: profile_data[:email] || user.email,
      name: profile_data[:name] || user.name,
      bio: profile_data[:bio] || user.bio,
      company: profile_data[:company],
      website: profile_data[:websiteUrl].presence || user.website,
      twitter: profile_data[:twitterUsername].presence || user.twitter,
      location: profile_data[:location],
      avatar_url: profile_data[:avatarUrl],
      github_data_updated_at: Time.current
    )

    # Process repositories into Project records
    repos = repos_data.map do |repo|
      {
        name: repo[:name],
        description: repo[:description],
        stars: repo[:stargazerCount],
        github_url: repo[:url],
        forks_count: repo.dig(:forks, :totalCount) || 0,
        size: repo[:diskUsage] || 0,
        topics: (repo.dig(:repositoryTopics, :nodes) || []).map { |t| t.dig(:topic, :name) }.compact,
        pushed_at: repo[:pushedAt]
      }
    end

    sync_projects!(user, repos)
  end

  # Sync GitHub repos to Project records with star snapshot tracking
  def self.sync_projects!(user, repos_data)
    current_urls = repos_data.map { |r| r[:github_url] || r[:url] }

    # Soft-archive projects no longer returned by GitHub
    user.projects.active.where.not(github_url: current_urls).update_all(archived: true)

    repos_data.each do |repo_data|
      url = repo_data[:github_url] || repo_data[:url]
      project = user.projects.find_or_initialize_by(github_url: url)

      project.assign_attributes(
        name: repo_data[:name],
        description: repo_data[:description],
        stars: repo_data[:stars].to_i,
        forks_count: repo_data[:forks_count].to_i,
        size: repo_data[:size].to_i,
        topics: repo_data[:topics] || [],
        pushed_at: repo_data[:pushed_at].present? ? Time.parse(repo_data[:pushed_at].to_s) : nil,
        archived: false
      )

      project.save!
      project.record_snapshot!
    end

    # Recalculate cached stats on user
    visible = user.projects.visible
    gained = visible.sum { |p| p.stars_gained }
    user.update!(
      github_repos_count: visible.count,
      github_stars_sum: visible.sum(:stars),
      stars_gained: gained
    )
  end

  # === Instance Methods for OAuth Sign-in (unchanged) ===

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
      username: auth_data.info.nickname,
      email: auth_data.info.email,
      name: raw_info.name || user.name,
      bio: raw_info.bio || user.bio,
      company: raw_info.company,
      website: raw_info.blog.presence || user.website,
      twitter: raw_info.twitter_username.presence || user.twitter,
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
        username: data["login"],
        email: data["email"] || user.email,
        name: data["name"] || user.name,
        bio: data["bio"] || user.bio,
        company: data["company"],
        website: data["blog"].presence || user.website,
        twitter: data["twitter_username"] || user.twitter,
        location: data["location"],
        avatar_url: data["avatar_url"]
      )
    else
      Rails.logger.error "Failed to fetch GitHub profile for #{user.username}: #{response.code} - #{response.message}"
      raise "GitHub API error: #{response.code}" unless response.code == "404"
    end
  end

  def fetch_and_store_repositories
    github_username = auth_data&.info&.nickname || user.username
    return unless github_username.present?

    repos = fetch_ruby_repositories(github_username)
    if repos.present?
      # Normalize key: REST API uses :url, sync_projects! expects :github_url
      repos.each { |r| r[:github_url] ||= r.delete(:url) }
      self.class.sync_projects!(user, repos)
    end
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
