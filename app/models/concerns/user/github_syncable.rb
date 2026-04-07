require "net/http"
require "json"

module User::GithubSyncable
  extend ActiveSupport::Concern

  GITHUB_GRAPHQL_ENDPOINT = "https://api.github.com/graphql"

  # Sync from OAuth callback data
  def sync_github_data_from_oauth!(auth_data)
    api_token = auth_data.credentials.token

    if auth_data.extra&.raw_info
      raw_info = auth_data.extra.raw_info
      update!(
        username: auth_data.info.nickname,
        email: auth_data.info.email,
        name: raw_info.name || name,
        bio: raw_info.bio || bio,
        company: raw_info.company,
        website: raw_info.blog.presence || website,
        twitter: raw_info.twitter_username.presence || twitter,
        location: raw_info.location,
        avatar_url: auth_data.info.image
      )
    end

    github_username = auth_data.info.nickname || username
    return unless github_username.present?

    repos = fetch_ruby_repositories(github_username, api_token)
    if repos.present?
      repos.each { |r| r[:github_url] ||= r.delete(:url) }
      self.class.sync_projects!(self, repos)
    end

    update!(github_data_updated_at: Time.current)

    # Assign to company team based on GitHub company field
    Team.find_or_create_for_user!(self)
  rescue => e
    Rails.logger.error "Failed to sync GitHub data for #{username}: #{e.message}"
  end

  class_methods do
    # Batch GraphQL fetch for multiple users
    def batch_sync_github_data!(users, api_token: nil)
      api_token ||= Rails.application.credentials.dig(:github, :api_token)
      return { updated: 0, failed: users.size, errors: [ "No API token configured" ] } unless api_token.present?

      users_with_usernames = users.select { |u| u.username.present? }
      return { updated: 0, failed: 0, errors: [] } if users_with_usernames.empty?

      query = build_batch_query(users_with_usernames)
      response = github_graphql_request(query, api_token, retries: 2)

      if response[:errors].present? && response[:data].nil?
        error_msg = response[:errors].first.to_s
        if error_msg.match?(/50[234]/) && users_with_usernames.size > 1
          Rails.logger.warn "Batch of #{users_with_usernames.size} failed with #{error_msg}, splitting in half..."
          mid = users_with_usernames.size / 2
          first_half = batch_sync_github_data!(users_with_usernames[0...mid], api_token: api_token)
          sleep(1)
          second_half = batch_sync_github_data!(users_with_usernames[mid..], api_token: api_token)

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
        user_data = response.dig(:data, :"user_#{index}")
        repos_data = response.dig(:data, :"repos_#{index}", :nodes)

        if user_data.nil?
          failed += 1
          errors << "User #{user.username} not found on GitHub"
          next
        end

        begin
          update_user_from_graphql(user, user_data, repos_data || [])
          Team.find_or_create_for_user!(user)
          updated += 1
        rescue => e
          failed += 1
          errors << "Failed to update #{user.username}: #{e.message}"
          Rails.logger.error "GraphQL batch update error for #{user.username}: #{e.message}"
        end
      end

      { updated: updated, failed: failed, errors: errors }
    end

    def sync_projects!(user, repos_data, force_snapshot: false)
      current_urls = repos_data.map { |r| r[:github_url] || r[:url] }
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
        project.record_snapshot!(force: force_snapshot)
      end

      visible = user.projects.visible
      gained = visible.sum { |p| p.stars_gained }
      user.update!(
        github_repos_count: visible.count,
        github_stars_sum: visible.sum(:stars),
        stars_gained: gained
      )
    end

    private

    def github_graphql_request(query, api_token, retries: 3)
      uri = URI(GITHUB_GRAPHQL_ENDPOINT)

      retries.times do |attempt|
        begin
          request = Net::HTTP::Post.new(uri)
          request["Content-Type"] = "application/json"
          request["Authorization"] = "Bearer #{api_token}"
          request.body = { query: query }.to_json

          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }

          if response.code == "200"
            return JSON.parse(response.body, symbolize_names: true)
          elsif %w[502 503 504].include?(response.code) && attempt < retries - 1
            sleep(2 ** (attempt + 1))
            next
          else
            return { errors: [ "HTTP #{response.code}: #{response.message}" ] }
          end
        rescue Net::OpenTimeout, Net::ReadTimeout => e
          if attempt < retries - 1
            sleep(2 ** (attempt + 1))
            next
          else
            return { errors: [ "Request timed out: #{e.message}" ] }
          end
        end
      end
    end

    def build_batch_query(users)
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

    def update_user_from_graphql(user, profile_data, repos_data)
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

      sync_projects!(user, repos, force_snapshot: true)
    end
  end

  private

  def fetch_ruby_repositories(github_username, api_token)
    uri = URI("https://api.github.com/users/#{github_username}/repos?per_page=100&sort=pushed")
    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/vnd.github.v3+json"
    request["Authorization"] = "Bearer #{api_token}" if api_token.present?

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }

    if response.code == "200"
      repos = JSON.parse(response.body)

      repos.select do |repo|
        next if repo["fork"]
        repo["language"] == "Ruby" ||
        repo["description"]&.downcase&.include?("ruby") ||
        repo["name"]&.downcase&.include?("ruby") ||
        repo["name"]&.downcase&.include?("rails")
      end.map do |repo|
        {
          name: repo["name"],
          description: repo["description"],
          stars: repo["stargazers_count"],
          url: repo["html_url"],
          forks_count: repo["forks_count"],
          size: repo["size"],
          topics: repo["topics"] || [],
          pushed_at: repo["pushed_at"]
        }
      end.sort_by { |r| -r[:stars] }
    else
      Rails.logger.error "GitHub API returned #{response.code} for #{github_username}: #{response.body}"
      []
    end
  end
end
