# frozen_string_literal: true

namespace :newsletter do
  desc "Send newsletter update to eligible users. Usage: rails newsletter:send[1]"
  task :send, [ :version ] => :environment do |_t, args|
    version = args[:version].to_i
    abort "Usage: rails newsletter:send[1]" if version.zero?

    excluded_usernames = %w[dhh matz pragdave amandaperino]

    users = User.where.not("email LIKE ?", "%@users.noreply.github.com")
                .where.not(username: excluded_usernames)
                .where(unsubscribed_from_newsletter: false)

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

  desc "Schedule newsletter for timezone-aware delivery. Usage: rails newsletter:schedule[1,2026-02-10]"
  task :schedule, [ :version, :date ] => :environment do |_t, args|
    version = args[:version].to_i
    date_str = args[:date]
    abort "Usage: rails newsletter:schedule[1,2026-02-10]" if version.zero? || date_str.blank?

    target_date = Date.parse(date_str)
    excluded_usernames = %w[dhh matz pragdave amandaperino]
    now = Time.current

    users = User.where.not("email LIKE ?", "%@users.noreply.github.com")
                .where.not(username: excluded_usernames)
                .where(unsubscribed_from_newsletter: false)

    scheduled_count = 0
    immediate_count = 0
    skipped_count = 0

    users.find_each do |user|
      if user.received_newsletter?(version)
        skipped_count += 1
        next
      end

      tz_name = user.timezone.presence || "Etc/UTC"
      tz = TZInfo::Timezone.get(tz_name)
      local_time = tz.local_time(target_date.year, target_date.month, target_date.day, 10, 10)
      utc_time = local_time.utc

      if utc_time > now
        ScheduledNewsletterJob.set(wait_until: utc_time).perform_later(user.id, version: version)
        scheduled_count += 1
      else
        ScheduledNewsletterJob.perform_later(user.id, version: version)
        immediate_count += 1
      end
    end

    puts "Newsletter v#{version} scheduled for #{target_date}:"
    puts "  Scheduled for 10:10 AM local: #{scheduled_count}"
    puts "  Immediate (local time already past): #{immediate_count}"
    puts "  Skipped (already received): #{skipped_count}" if skipped_count > 0
  end

  desc "Preview timezone-aware schedule. Usage: rails newsletter:preview_schedule[1,2026-02-10]"
  task :preview_schedule, [ :version, :date ] => :environment do |_t, args|
    version = args[:version].to_i
    date_str = args[:date]
    abort "Usage: rails newsletter:preview_schedule[1,2026-02-10]" if version.zero? || date_str.blank?

    target_date = Date.parse(date_str)
    excluded_usernames = %w[dhh matz pragdave amandaperino]
    now = Time.current

    users = User.where.not("email LIKE ?", "%@users.noreply.github.com")
                .where.not(username: excluded_usernames)
                .where(unsubscribed_from_newsletter: false)

    tz_counts = Hash.new(0)
    utc_times = []
    past_count = 0
    skipped_count = 0

    users.find_each do |user|
      if user.received_newsletter?(version)
        skipped_count += 1
        next
      end

      tz_name = user.timezone.presence || "Etc/UTC"
      tz_counts[tz_name] += 1

      tz = TZInfo::Timezone.get(tz_name)
      local_time = tz.local_time(target_date.year, target_date.month, target_date.day, 10, 10)
      utc_time = local_time.utc
      utc_times << utc_time

      past_count += 1 if utc_time <= now
    end

    eligible = tz_counts.values.sum
    puts "Newsletter v#{version} preview for #{target_date}:"
    puts "  Eligible recipients: #{eligible}"
    puts "  Skipped (already received): #{skipped_count}" if skipped_count > 0
    puts ""
    puts "Timezone distribution:"
    tz_counts.sort_by { |_, count| -count }.each do |tz, count|
      puts "  #{tz}: #{count}"
    end

    if utc_times.any?
      puts ""
      puts "UTC delivery window:"
      puts "  Earliest: #{utc_times.min.strftime('%Y-%m-%d %H:%M UTC')}"
      puts "  Latest:   #{utc_times.max.strftime('%Y-%m-%d %H:%M UTC')}"
      puts "  Would send immediately (past local time): #{past_count}" if past_count > 0
    end
  end

  desc "Backfill timezones for users with coordinates. Usage: rails newsletter:backfill_timezones"
  task backfill_timezones: :environment do
    users = User.where.not(latitude: nil).where.not(longitude: nil).where(timezone: nil)
    total = users.count
    updated = 0

    puts "Backfilling timezones for #{total} users..."

    users.find_each do |user|
      timezone = TimezoneResolver.resolve(user.latitude, user.longitude)
      user.update_columns(timezone: timezone)
      updated += 1
    end

    puts "Done. Updated #{updated} users."
  end

  desc "Preview how many users will receive the newsletter. Usage: rails newsletter:count[1]"
  task :count, [ :version ] => :environment do |_t, args|
    version = args[:version].to_i
    excluded_usernames = %w[dhh matz pragdave amandaperino]

    total = User.count
    excluded_noreply = User.where("email LIKE ?", "%@users.noreply.github.com").count
    excluded_specific = User.where(username: excluded_usernames).count

    unsubscribed = User.where(unsubscribed_from_newsletter: true).count

    eligible_scope = User.where.not("email LIKE ?", "%@users.noreply.github.com")
                         .where.not(username: excluded_usernames)
                         .where(unsubscribed_from_newsletter: false)

    eligible = eligible_scope.count

    puts "Total users: #{total}"
    puts "Excluded (noreply emails): #{excluded_noreply}"
    puts "Excluded (specific usernames): #{excluded_specific}"
    puts "Unsubscribed: #{unsubscribed}"
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
