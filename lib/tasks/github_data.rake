namespace :github do
  desc "Update GitHub data for all users using the UpdateGithubDataJob"
  task update_all_job: :environment do
    puts "Starting GitHub data update job for all users..."
    UpdateGithubDataJob.perform_now
    puts "Job completed. Check logs for details."
  end

  desc "Update GitHub data for all users (requires GitHub API token)"
  task update_all: :environment do
    puts "Updating GitHub data for all users..."

    User.find_each do |user|
      begin
        print "Updating #{user.username}... "

        # Fetch public user data from GitHub API
        require "net/http"
        require "json"

        uri = URI("https://api.github.com/users/#{user.username}")
        request = Net::HTTP::Get.new(uri)
        request["Accept"] = "application/vnd.github.v3+json"

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

          # Fetch repositories
          repos_uri = URI("https://api.github.com/users/#{user.username}/repos?per_page=100&sort=updated")
          repos_request = Net::HTTP::Get.new(repos_uri)
          repos_request["Accept"] = "application/vnd.github.v3+json"

          repos_response = Net::HTTP.start(repos_uri.hostname, repos_uri.port, use_ssl: true) do |http|
            http.request(repos_request)
          end

          if repos_response.code == "200"
            repos = JSON.parse(repos_response.body)

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
            end.sort_by { |r| -r[:stars] }

            user.update!(
              github_repos: ruby_repos.to_json,
              github_data_updated_at: Time.current
            )

            puts "✓ Updated with #{ruby_repos.size} original Ruby repos (excluding forks)"
          else
            puts "✗ Failed to fetch repos: #{repos_response.code}"
          end
        else
          puts "✗ Failed: #{response.code}"
        end

        # Be nice to GitHub API rate limits
        sleep 0.5
      rescue => e
        puts "✗ Error: #{e.message}"
      end
    end

    puts "Done!"
  end

  desc "Update GitHub data for a specific user"
  task :update_user, [ :username ] => :environment do |t, args|
    unless args[:username]
      puts "Usage: rails github:update_user[username]"
      exit 1
    end

    user = User.find_by(username: args[:username])
    unless user
      puts "User not found: #{args[:username]}"
      exit 1
    end

    print "Updating #{user.username}... "

    begin
      require "net/http"
      require "json"

      uri = URI("https://api.github.com/users/#{user.username}")
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github.v3+json"

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

        # Fetch repositories
        repos_uri = URI("https://api.github.com/users/#{user.username}/repos?per_page=100&sort=updated")
        repos_request = Net::HTTP::Get.new(repos_uri)
        repos_request["Accept"] = "application/vnd.github.v3+json"

        repos_response = Net::HTTP.start(repos_uri.hostname, repos_uri.port, use_ssl: true) do |http|
          http.request(repos_request)
        end

        if repos_response.code == "200"
          repos = JSON.parse(repos_response.body)

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
          end.sort_by { |r| -r[:stars] }

          user.update!(
            github_repos: ruby_repos.to_json,
            github_data_updated_at: Time.current
          )

          puts "✓ Updated with #{ruby_repos.size} original Ruby repos (excluding forks)"
          puts "\nProfile data:"
          puts "  Name: #{user.name}"
          puts "  Bio: #{user.bio}"
          puts "  Company: #{user.company}"
          puts "  Location: #{user.location}"
          puts "  Website: #{user.website}"
          puts "  Twitter: #{user.twitter}"
          puts "\nTop Ruby repositories:"
          ruby_repos.first(5).each do |repo|
            puts "  - #{repo[:name]} (⭐ #{repo[:stars]})"
          end
        else
          puts "✗ Failed to fetch repos: #{repos_response.code}"
        end
      else
        puts "✗ Failed: #{response.code}"
      end
    rescue => e
      puts "✗ Error: #{e.message}"
    end
  end
end
