class GithubDataFetcher
  attr_reader :user, :auth_data

  def initialize(user, auth_data)
    @user = user
    @auth_data = auth_data
  end

  def fetch_and_update!
    update_basic_profile
    fetch_and_store_repositories
    user.update!(github_data_updated_at: Time.current)
  end

  private

  def update_basic_profile
    raw_info = auth_data.extra.raw_info
    
    user.update!(
      name: raw_info.name,
      bio: raw_info.bio,
      company: raw_info.company,
      website: extract_website(raw_info),
      twitter: extract_twitter(raw_info),
      location: raw_info.location,
      avatar_url: auth_data.info.image
    )
  end

  def extract_website(raw_info)
    # GitHub API returns blog as the website field
    raw_info.blog.presence
  end

  def extract_twitter(raw_info)
    # Twitter username is stored in twitter_username field
    raw_info.twitter_username.presence
  end

  def fetch_and_store_repositories
    # Fetch user's public repositories from GitHub API
    github_username = auth_data.info.nickname
    token = auth_data.credentials.token
    
    # Store repos as JSON in the github_repos field
    repos = fetch_ruby_repositories(github_username, token)
    user.update!(github_repos: repos.to_json) if repos.present?
  rescue => e
    Rails.logger.error "Failed to fetch GitHub repositories: #{e.message}"
  end

  def fetch_ruby_repositories(username, token = nil)
    require 'net/http'
    require 'json'
    
    uri = URI("https://api.github.com/users/#{username}/repos?per_page=100&sort=updated")
    
    request = Net::HTTP::Get.new(uri)
    request['Accept'] = 'application/vnd.github.v3+json'
    request['Authorization'] = "Bearer #{token}" if token
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
    
    if response.code == '200'
      repos = JSON.parse(response.body)
      
      # Filter for Ruby repositories and select relevant fields
      ruby_repos = repos.select do |repo|
        repo['language'] == 'Ruby' || 
        repo['description']&.downcase&.include?('ruby') ||
        repo['name']&.downcase&.include?('ruby') ||
        repo['name']&.downcase&.include?('rails')
      end.map do |repo|
        {
          name: repo['name'],
          description: repo['description'],
          stars: repo['stargazers_count'],
          url: repo['html_url'],
          language: repo['language'],
          updated_at: repo['updated_at'],
          fork: repo['fork']
        }
      end.sort_by { |r| -r[:stars] } # Sort by stars descending
      
      ruby_repos
    else
      Rails.logger.error "GitHub API returned #{response.code}: #{response.body}"
      []
    end
  end
end