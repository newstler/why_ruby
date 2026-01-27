require "test_helper"

class TestimonialMailerTest < ActionMailer::TestCase
  test "invitation email" do
    user = users(:user_no_testimonial)
    email = TestimonialMailer.invitation(user)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ user.email ], email.to
    assert_equal "Share why you love Ruby!", email.subject
    assert_match "Why do you love Ruby?", email.body.encoded
    assert_match user.display_name, email.body.encoded
  end
end
