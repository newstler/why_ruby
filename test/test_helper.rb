ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Configure OmniAuth for testing
OmniAuth.config.test_mode = true

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all
  end
end

module SignInHelper
  # Sign in by directly setting the session via a test-only endpoint
  def sign_in(user)
    # Open a session so we can set user_id directly
    post "/_test_sign_in", params: { user_id: user.id }
  end

  def sign_out(_user = nil)
    delete destroy_user_session_path
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelper
end
