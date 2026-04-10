require "test_helper"

class Post::SvgSanitizableTest < ActiveSupport::TestCase
  test "removes script elements from SVG" do
    svg = "<svg><script>alert('xss')</script><path d='M0 0'/></svg>"
    result = Post.sanitize_svg(svg)
    assert_not_includes result, "<script"
    assert_not_includes result, "</script>"
  end

  test "removes event handler attributes" do
    svg = "<svg><path onclick='alert(1)' onload='evil()' d='M0 0'/></svg>"
    result = Post.sanitize_svg(svg)
    assert_not_includes result, "onclick"
    assert_not_includes result, "onload"
  end

  test "removes javascript: href attributes" do
    svg = "<svg><a href='javascript:alert(1)'><text>click</text></a></svg>"
    result = Post.sanitize_svg(svg)
    assert_not_includes result, "javascript:"
  end

  test "preserves allowed SVG elements" do
    svg = "<svg viewBox='0 0 100 100'><path d='M0 0'/><rect x='0' y='0' width='10' height='10'/><circle cx='50' cy='50' r='10'/></svg>"
    result = Post.sanitize_svg(svg)
    assert_includes result, "path"
    assert_includes result, "rect"
    assert_includes result, "circle"
  end

  test "preserves viewBox attribute" do
    svg = "<svg viewBox='0 0 200 200'><path d='M0 0'/></svg>"
    result = Post.sanitize_svg(svg)
    assert_includes result, "viewBox"
    assert_includes result, "0 0 200 200"
  end

  test "returns empty string for nil input" do
    assert_equal "", Post.sanitize_svg(nil)
  end

  test "returns empty string for blank input" do
    assert_equal "", Post.sanitize_svg("")
    assert_equal "", Post.sanitize_svg("   ")
  end

  test "returns empty string for non-SVG input" do
    result = Post.sanitize_svg("<div><p>Not SVG</p></div>")
    assert_equal "", result
  end
end
