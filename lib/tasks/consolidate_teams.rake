namespace :teams do
  desc "Consolidate teams by company: assign users to company-named teams and remove old personal teams"
  task consolidate_by_company: :environment do
    users = User.where.not(company: [ nil, "" ])
    puts "Processing #{users.count} users with company data..."

    created = 0
    assigned = 0

    users.find_each do |user|
      team = Team.find_by(name: user.company)

      unless team
        team = Team.create!(name: user.company)
        created += 1
        puts "  Created team: #{user.company}"
      end

      unless user.member_of?(team)
        team.memberships.create!(user: user, role: "member")
        assigned += 1
        puts "  Assigned #{user.username} -> #{user.company}"
      end
    end

    # Remove old personal teams for users who now have a company team
    removed = 0
    Team.where("name LIKE ?", "%'s Team").find_each do |personal_team|
      member = personal_team.users.first
      next unless member&.company.present?

      company_team = Team.find_by(name: member.company)
      next unless company_team && member.member_of?(company_team)

      personal_team.destroy!
      removed += 1
      puts "  Removed personal team: #{personal_team.name}"
    end

    puts "\nDone! Created #{created} teams, assigned #{assigned} users, removed #{removed} personal teams."
  end
end
