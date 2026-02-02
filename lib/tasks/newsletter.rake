# frozen_string_literal: true

namespace :newsletter do
  desc "Send newsletter update to eligible users. Usage: rails newsletter:send[1]"
  task :send, [ :version ] => :environment do |_t, args|
    version = args[:version].to_i
    abort "Usage: rails newsletter:send[1]" if version.zero?

    excluded_usernames = %w[dhh matz pragdave amandaperino]

    users = User.where.not("email LIKE ?", "%@users.noreply.github.com")
                .where.not(username: excluded_usernames)

    sent_count = 0
    skipped_count = 0

    users.find_each do |user|
      if user.received_newsletter?(version)
        skipped_count += 1
        next
      end

      NewsletterMailer.update(user, version: version).deliver_later
      user.record_newsletter_sent!(version)
      sent_count += 1
    end

    puts "Queued #{sent_count} emails for update v#{version}"
    puts "Skipped #{skipped_count} users (already received)" if skipped_count > 0
  end

  desc "Preview how many users will receive the newsletter. Usage: rails newsletter:count[1]"
  task :count, [ :version ] => :environment do |_t, args|
    version = args[:version].to_i
    excluded_usernames = %w[dhh matz pragdave amandaperino]

    total = User.count
    excluded_noreply = User.where("email LIKE ?", "%@users.noreply.github.com").count
    excluded_specific = User.where(username: excluded_usernames).count

    eligible_scope = User.where.not("email LIKE ?", "%@users.noreply.github.com")
                         .where.not(username: excluded_usernames)

    eligible = eligible_scope.count

    puts "Total users: #{total}"
    puts "Excluded (noreply emails): #{excluded_noreply}"
    puts "Excluded (specific usernames): #{excluded_specific}"
    puts "Eligible recipients: #{eligible}"

    if version > 0
      already_received = eligible_scope.select { |u| u.received_newsletter?(version) }.count
      will_receive = eligible - already_received
      puts ""
      puts "For version #{version}:"
      puts "  Already received: #{already_received}"
      puts "  Will receive: #{will_receive}"
    end
  end
end
