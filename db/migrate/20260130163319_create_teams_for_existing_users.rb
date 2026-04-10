class CreateTeamsForExistingUsers < ActiveRecord::Migration[8.2]
  def up
    # Skip model callbacks by using raw SQL/ActiveRecord base operations
    User.find_each do |user|
      team_name = "#{user.name || user.email.to_s.split('@').first}'s Team"
      slug = team_name.parameterize

      # Ensure unique slug
      base_slug = slug
      counter = 1
      while Team.exists?(slug: slug)
        slug = "#{base_slug}-#{counter}"
        counter += 1
      end

      # Use insert to bypass model callbacks (api_key column may not exist yet)
      team_id = SecureRandom.uuid_v7
      execute <<~SQL
        INSERT INTO teams (id, name, slug, created_at, updated_at)
        VALUES ('#{team_id}', #{connection.quote(team_name)}, #{connection.quote(slug)}, datetime('now'), datetime('now'))
      SQL

      membership_id = SecureRandom.uuid_v7
      execute <<~SQL
        INSERT INTO memberships (id, user_id, team_id, role, created_at, updated_at)
        VALUES ('#{membership_id}', '#{user.id}', '#{team_id}', 'owner', datetime('now'), datetime('now'))
      SQL

      # Assign all user's chats to their team
      Chat.where(user: user, team: nil).update_all(team_id: team_id)
    end
  end

  def down
    Membership.where(role: "owner").find_each do |membership|
      team = membership.team
      if team.memberships.count == 1
        team.chats.update_all(team_id: nil)
        team.destroy
      end
    end
  end
end
