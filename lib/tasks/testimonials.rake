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
end
