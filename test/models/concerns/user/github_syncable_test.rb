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

  test "batch_sync_github_data! preserves existing bio when GitHub returns nil" do
    @user.update_columns(bio: "Loves Ruby since 2005")

    stub_graphql_user(bio: nil)

    result = User.batch_sync_github_data!([ @user ], api_token: "token")

    assert_equal 1, result[:updated], result[:errors].inspect
    assert_equal "Loves Ruby since 2005", @user.reload.bio
  end

  test "batch_sync_github_data! preserves existing bio when GitHub returns empty string" do
    @user.update_columns(bio: "Loves Ruby since 2005")

    stub_graphql_user(bio: "")

    result = User.batch_sync_github_data!([ @user ], api_token: "token")

    assert_equal 1, result[:updated], result[:errors].inspect
    assert_equal "Loves Ruby since 2005", @user.reload.bio
  end

  test "batch_sync_github_data! updates bio when GitHub returns a non-blank value" do
    @user.update_columns(bio: "Old bio")

    stub_graphql_user(bio: "Fresh bio from GitHub")

    result = User.batch_sync_github_data!([ @user ], api_token: "token")

    assert_equal 1, result[:updated], result[:errors].inspect
    assert_equal "Fresh bio from GitHub", @user.reload.bio
  end

  private

  def stub_graphql_user(bio:)
    stub_request(:post, User::GithubSyncable::GITHUB_GRAPHQL_ENDPOINT).to_return(
      status: 200,
      body: {
        data: {
          user_0: { login: "octocat", name: "The Octocat", email: nil, bio: bio, company: nil, websiteUrl: nil, twitterUsername: nil, location: nil, avatarUrl: "https://example.com/a.png" },
          repos_0: { nodes: [] }
        }
      }.to_json
    )
  end
end
