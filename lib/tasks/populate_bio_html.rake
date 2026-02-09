namespace :users do
  desc "Populate bio_html for all users with bios"
  task populate_bio_html: :environment do
    puts "Populating bio_html for users with bios..."

    users_updated = 0
    User.where.not(bio: [ nil, "" ]).find_each do |user|
      user.update_column(:bio_html, User.linkify_bio(user.bio))
      users_updated += 1
      print "."
    end

    puts "\nUpdated #{users_updated} users."
  end
end
