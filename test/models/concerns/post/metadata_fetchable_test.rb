require "test_helper"
require "webmock/minitest"

class Post::MetadataFetchableTest < ActiveSupport::TestCase
  setup do
    @user = users(:user_with_testimonial)
    @category = categories(:general)
    WebMock.enable!
    WebMock.disable_net_connect!
  end

  teardown do
    WebMock.reset!
    WebMock.allow_net_connect!
  end

  def build_link_post(url)
    Post.new(title: "Test Link", post_type: "link", url: url, user: @user, category: @category)
  end

  test "fetch_metadata! extracts og:title from HTML" do
    stub_request(:get, "https://example.com/article").to_return(
      status: 200,
      body: <<~HTML,
        <html>
          <head>
            <meta property="og:title" content="My Great Article" />
          </head>
          <body><p>Content here</p></body>
        </html>
      HTML
      headers: { "Content-Type" => "text/html" }
    )

    post = build_link_post("https://example.com/article")
    metadata = post.fetch_metadata!

    assert_equal "My Great Article", metadata[:title]
  end

  test "fetch_metadata! extracts og:description" do
    stub_request(:get, "https://example.com/article").to_return(
      status: 200,
      body: <<~HTML,
        <html>
          <head>
            <meta property="og:title" content="Article Title" />
            <meta property="og:description" content="A detailed description of the article." />
          </head>
          <body></body>
        </html>
      HTML
      headers: { "Content-Type" => "text/html" }
    )

    post = build_link_post("https://example.com/article")
    metadata = post.fetch_metadata!

    assert_equal "A detailed description of the article.", metadata[:description]
  end

  test "fetch_metadata! returns empty hash for blank url" do
    post = build_link_post("")
    metadata = post.fetch_metadata!
    assert_equal({}, metadata)
  end

  test "fetch_metadata! handles connection errors gracefully" do
    stub_request(:get, "https://example.com/broken").to_raise(Net::OpenTimeout)

    post = build_link_post("https://example.com/broken")
    metadata = post.fetch_metadata!

    assert_equal({}, metadata)
  end

  test "fetch_external_content extracts page text" do
    stub_request(:get, "https://example.com/page").to_return(
      status: 200,
      body: <<~HTML,
        <html>
          <head>
            <meta property="og:title" content="Page Title" />
            <meta property="og:description" content="Page description." />
          </head>
          <body>
            <main>This is the main content of the page. It has enough text to be extracted properly.</main>
          </body>
        </html>
      HTML
      headers: { "Content-Type" => "text/html" }
    )

    post = build_link_post("https://example.com/page")
    content = post.fetch_external_content

    assert_not_nil content
    assert_includes content, "Page Title"
  end
end
