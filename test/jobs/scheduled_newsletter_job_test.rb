# frozen_string_literal: true

require "test_helper"

class ScheduledNewsletterJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  test "delivers newsletter to eligible user" do
    user = users(:user_with_testimonial)

    assert_emails 1 do
      ScheduledNewsletterJob.perform_now(user.id, version: 1)
    end

    assert user.reload.received_newsletter?(1)
  end

  test "skips user who already received this version" do
    user = users(:user_with_testimonial)
    user.record_newsletter_sent!(1)

    assert_emails 0 do
      ScheduledNewsletterJob.perform_now(user.id, version: 1)
    end
  end

  test "skips unsubscribed user" do
    user = users(:user_with_testimonial)
    user.update!(unsubscribed_from_newsletter: true)

    assert_emails 0 do
      ScheduledNewsletterJob.perform_now(user.id, version: 1)
    end
  end

  test "skips noreply email user" do
    user = users(:user_with_testimonial)
    user.update_columns(email: "12345+test@users.noreply.github.com")

    assert_emails 0 do
      ScheduledNewsletterJob.perform_now(user.id, version: 1)
    end
  end

  test "skips excluded username" do
    user = users(:user_with_testimonial)
    user.update_columns(username: "dhh")

    assert_emails 0 do
      ScheduledNewsletterJob.perform_now(user.id, version: 1)
    end
  end

  test "handles nonexistent user gracefully" do
    assert_nothing_raised do
      ScheduledNewsletterJob.perform_now("nonexistent-id", version: 1)
    end
  end
end
