class MigrateGithubReposToProjects < ActiveRecord::Migration[8.2]
  def up
    # Use yesterday so that the next GitHub update (which creates today's snapshots)
    # immediately produces a visible stars_gained delta
    yesterday = Date.yesterday

    User.where.not(github_repos: [ nil, "", "[]" ]).find_each do |user|
      repos = begin
        JSON.parse(user.github_repos, symbolize_names: true)
      rescue JSON::ParserError
        next
      end

      hidden_urls = begin
        JSON.parse(user.hidden_repos || "[]")
      rescue JSON::ParserError
        []
      end

      repos.each do |repo|
        project = Project.create!(
          user_id: user.id,
          name: repo[:name],
          description: repo[:description],
          stars: repo[:stars].to_i,
          github_url: repo[:url],
          forks_count: repo[:forks_count].to_i,
          size: repo[:size].to_i,
          topics: repo[:topics] || [],
          pushed_at: repo[:pushed_at].present? ? Time.parse(repo[:pushed_at]) : nil,
          hidden: hidden_urls.include?(repo[:url])
        )

        StarSnapshot.create!(
          project_id: project.id,
          stars: repo[:stars].to_i,
          recorded_on: yesterday
        )
      end

      user.update_columns(stars_gained: 0)
    end
  end

  def down
    StarSnapshot.delete_all
    Project.delete_all
    User.update_all(stars_gained: 0)
  end
end
