# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class User::GithubSyncableTest < ActiveSupport::TestCase
  setup do
    WebMock.disable_net_connect!(allow_localhost: true)
    @user = users(:user_with_testimonial)
    @user.update_columns(username: "octocat")
  end

  teardown do
    WebMock.reset!
    WebMock.allow_net_connect!
  end

  # Skip the exponential backoff so tests run fast.
  setup { User.singleton_class.send(:define_method, :sleep) { |_| } }
  teardown { User.singleton_class.send(:remove_method, :sleep) }

  test "batch_sync_github_data! retries on EOFError and succeeds on second attempt" do
    stub_request(:post, User::GithubSyncable::GITHUB_GRAPHQL_ENDPOINT)
      .to_raise(EOFError.new("end of file reached"))
      .then.to_return(
        status: 200,
        body: {
          data: {
            user_0: { login: "octocat", name: "The Octocat", email: nil, bio: nil, company: nil, websiteUrl: nil, twitterUsername: nil, location: nil, avatarUrl: "https://example.com/a.png" },
            repos_0: { nodes: [] }
          }
        }.to_json
      )

    result = User.batch_sync_github_data!([ @user ], api_token: "token")

    assert_equal 1, result[:updated], result[:errors].inspect
    assert_equal 0, result[:failed]
  end

  test "batch_sync_github_data! returns a network error after exhausting retries" do
    stub_request(:post, User::GithubSyncable::GITHUB_GRAPHQL_ENDPOINT)
      .to_raise(EOFError.new("end of file reached"))

    result = User.batch_sync_github_data!([ @user ], api_token: "token")

    assert_equal 0, result[:updated]
    assert_equal 1, result[:failed]
    assert_match(/EOFError/, result[:errors].first.to_s)
  end
end
