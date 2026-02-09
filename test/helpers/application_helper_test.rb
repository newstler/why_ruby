require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "linkify_bio returns empty string for blank input" do
    assert_equal "", linkify_bio(nil)
    assert_equal "", linkify_bio("")
  end

  test "linkify_bio converts URLs to links" do
    bio = "Check out example.com for more"
    result = linkify_bio(bio)

    assert_includes result, 'href="https://example.com"'
    assert_includes result, 'target="_blank"'
    assert_includes result, ">example.com</a>"
  end

  test "linkify_bio handles URLs with protocol" do
    bio = "Visit https://example.com today"
    result = linkify_bio(bio)

    assert_includes result, 'href="https://example.com"'
    assert_includes result, ">https://example.com</a>"
  end

  test "linkify_bio converts GitHub @mentions to links" do
    bio = "Co-founded @freshflowai"
    result = linkify_bio(bio)

    assert_includes result, 'href="https://github.com/freshflowai"'
    assert_includes result, ">@freshflowai</a>"
  end

  test "linkify_bio handles multiple URLs and mentions" do
    bio = "Building tools at chatwithwork.com, rubyllm.com and more. Co-founded @freshflowai."
    result = linkify_bio(bio)

    assert_includes result, 'href="https://chatwithwork.com"'
    assert_includes result, 'href="https://rubyllm.com"'
    assert_includes result, 'href="https://github.com/freshflowai"'
  end

  test "linkify_bio excludes trailing punctuation from URLs" do
    bio = "Check chatwithwork.com, and rubyllm.com."
    result = linkify_bio(bio)

    assert_includes result, 'href="https://chatwithwork.com"'
    assert_includes result, ">chatwithwork.com</a>,"
    assert_includes result, 'href="https://rubyllm.com"'
    assert_includes result, ">rubyllm.com</a>."
  end

  test "linkify_bio escapes HTML to prevent XSS" do
    bio = "<script>alert('xss')</script> Check example.com"
    result = linkify_bio(bio)

    refute_includes result, "<script>"
    assert_includes result, "&lt;script&gt;"
  end

  test "linkify_bio handles @mention at start of text" do
    bio = "@rubyonrails is great"
    result = linkify_bio(bio)

    assert_includes result, 'href="https://github.com/rubyonrails"'
  end
end
