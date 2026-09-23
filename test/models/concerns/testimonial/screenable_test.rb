require "test_helper"

class Testimonial::ScreenableTest < ActiveSupport::TestCase
  # A quote long enough to pass the 140-char minimum, so screening is what decides.
  def build(quote)
    Testimonial.new(user: users(:user_no_testimonial), quote: quote)
  end

  test "flags a quote containing a bare URL" do
    t = build("I love Ruby because it lets me ship fast and the community is wonderful to be around every single day of the week. Read my blog here: https://medium.com/@someone")
    assert t.self_promotional?
    assert_match(/link/i, t.screening_feedback)
  end

  test "flags a quote containing a www address" do
    t = build("I love Ruby because it is elegant and expressive and has been my favourite language for more than a decade now, truly. Visit www.example.com for more")
    assert t.self_promotional?
  end

  test "flags a quote containing a bare domain" do
    t = build("I love Ruby because it is elegant and expressive and has been my favourite language for more than a decade now, truly great. Check rubygrowthlabs.com")
    assert t.self_promotional?
  end

  test "flags a quote containing an email address" do
    t = build("I love Ruby because it is elegant and expressive and has been my favourite language for more than a decade now, truly. Email me at hello@example.org")
    assert t.self_promotional?
  end

  test "flags a quote with a hire-me call to action" do
    t = build("Ruby is the best language for AI-powered development and we ship at tremendous speed using agents on the majestic monolith. I help founders build Rails apps fast.")
    assert t.self_promotional?
    assert_match(/pitch/i, t.screening_feedback)
  end

  test "flags a quote that is a services pitch" do
    t = build("Ruby and Rails are a wonderful combination that I have relied on for years to deliver real value to clients quickly. Contact me if you need help with yours!")
    assert t.self_promotional?
  end

  test "does not flag an ordinary heartfelt testimonial" do
    t = build("I love Ruby because it makes programming feel human. The language reads almost like plain English, which lets me focus on solving real problems instead of fighting syntax.")
    assert_not t.self_promotional?
    assert_nil t.screening_feedback
  end

  test "does not flag a quote that merely mentions Rails and gems" do
    t = build("I love Ruby because the ecosystem has already solved the hard problems for you. From gems to standard libraries, the tools are mature and concise, which lets me prototype rapidly.")
    assert_not t.self_promotional?
  end

  test "does not flag a quote mentioning version numbers or decimals" do
    t = build("I have loved Ruby since version 1.8 and every release since has made the language better without ever losing the warmth and clarity that drew me to it in the first place.")
    assert_not t.self_promotional?
  end

  test "does not flag a quote using the word visit innocently" do
    t = build("Every time I visit an old Ruby codebase of mine I can still read it perfectly, which says everything about how well this language ages over the years and years.")
    assert_not t.self_promotional?
  end

  test "screening runs on validation and blocks a promotional quote" do
    t = build("I love Ruby because it is elegant and expressive and has been my favourite language for more than a decade now, truly. Visit rubygrowthlabs.com")
    assert_not t.valid?
    assert t.errors[:quote].any?
  end
end
