namespace :testimonials do
  desc "Send testimonial invitation emails to users without testimonials"
  task send_invitations: :environment do
    users = User.left_joins(:testimonial).where(testimonials: { id: nil }).where.not(email: nil)
    count = 0

    users.find_each do |user|
      TestimonialMailer.invitation(user).deliver_later
      count += 1
    end

    puts "Sent #{count} testimonial invitation emails."
  end

  desc "Unpublish a testimonial and tell its author why. Usage: rake 'testimonials:reject[username,reason]'"
  task :reject, [ :username, :reason ] => :environment do |_t, args|
    username = args[:username].presence or abort "Usage: rake 'testimonials:reject[username,reason]'"
    reason = args[:reason].presence || "This testimonial was removed because it does not read as a personal statement about Ruby."

    testimonial = find_testimonial!(username)

    testimonial.update_columns(
      published: false,
      reject_reason: "quote",
      ai_feedback: reason
    )

    puts "Unpublished #{username}."
    puts "  Reason shown to author: #{reason}"
    puts "  Quote kept in the database. Re-publish with: rake 'testimonials:publish[#{username}]'"
  end

  desc "Re-publish a previously rejected testimonial. Usage: rake 'testimonials:publish[username]'"
  task :publish, [ :username ] => :environment do |_t, args|
    username = args[:username].presence or abort "Usage: rake 'testimonials:publish[username]'"
    testimonial = find_testimonial!(username)

    testimonial.update_columns(published: true, reject_reason: nil, ai_feedback: nil)
    puts "Re-published #{username}."
  end

  desc "List published testimonials that trip the self-promotion screen"
  task screen: :environment do
    flagged = Testimonial.published.includes(:user).select(&:self_promotional?)

    if flagged.empty?
      puts "No published testimonial trips the self-promotion screen."
      next
    end

    puts "#{flagged.size} published testimonial(s) flagged:\n\n"
    flagged.each do |t|
      puts "  #{t.user.username}"
      puts "    #{t.screening_feedback}"
      puts "    #{t.quote.truncate(120)}"
      puts "    reject with: rake 'testimonials:reject[#{t.user.username}]'"
      puts
    end
  end

  desc "Translate non-English testimonials to English, keeping the original. Usage: rake testimonials:translate or 'testimonials:translate[username]'"
  task :translate, [ :username ] => :environment do |_t, args|
    scope = if args[:username].present?
              Testimonial.joins(:user).where(users: { username: args[:username] })
    else
              Testimonial.where(quote_original: nil).where.not(quote: [ nil, "" ])
    end

    translated = 0
    scope.includes(:user).find_each do |testimonial|
      next unless testimonial.needs_translation?

      if testimonial.translate_to_english!
        translated += 1
        puts "Translated #{testimonial.user.username} (#{testimonial.quote_language} → en)"
        puts "  original: #{testimonial.quote_original.truncate(90)}"
        puts "  english:  #{testimonial.quote.truncate(90)}"
      end
    end

    puts "\nTranslated #{translated} testimonial(s). Originals kept in quote_original."
    puts "Run 'rake testimonials:regenerate[username]' to rewrite AI fields from the English text." if translated.positive?
  end

  desc "Regenerate heading, subheading and body from the current quote. Usage: rake 'testimonials:regenerate[username]'"
  task :regenerate, [ :username ] => :environment do |_t, args|
    username = args[:username].presence or abort "Usage: rake 'testimonials:regenerate[username]'"
    testimonial = find_testimonial!(username)

    puts "Regenerating for #{username}..."
    testimonial.update_columns(ai_attempts: 0, ai_feedback: nil, reject_reason: nil)
    testimonial.generate_ai_fields!
    testimonial.reload

    puts "  heading:    #{testimonial.heading}"
    puts "  subheading: #{testimonial.subheading}"
    puts "  body:       #{testimonial.body_text}"
    puts "  published:  #{testimonial.published?}"
  end

  desc "Replace a quote and regenerate everything from it. Usage: rake 'testimonials:rewrite[username,new quote text]'"
  task :rewrite, [ :username, :quote ] => :environment do |_t, args|
    username = args[:username].presence or abort "Usage: rake 'testimonials:rewrite[username,new quote]'"
    new_quote = args[:quote].presence or abort "Provide the new quote text as the second argument."

    testimonial = find_testimonial!(username)
    puts "Was: #{testimonial.quote}"

    testimonial.system_generated = true
    unless testimonial.update(quote: new_quote)
      abort "Rejected: #{testimonial.errors.full_messages.to_sentence}"
    end

    puts "Now: #{testimonial.quote}"
    puts "Regenerating AI fields..."
    testimonial.update_columns(ai_attempts: 0, ai_feedback: nil, reject_reason: nil)
    testimonial.generate_ai_fields!
    testimonial.reload

    puts "  heading:    #{testimonial.heading}"
    puts "  subheading: #{testimonial.subheading}"
    puts "  body:       #{testimonial.body_text}"
    puts "  published:  #{testimonial.published?}"
  end

  def find_testimonial!(username)
    user = User.find_by(username: username) or abort "No user named #{username}."
    user.testimonial or abort "#{username} has no testimonial."
  end
end
