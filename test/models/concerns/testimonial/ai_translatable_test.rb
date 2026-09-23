require "test_helper"

class Testimonial::AiTranslatableTest < ActiveSupport::TestCase
  setup do
    @testimonial = testimonials(:published)
  end

  test "needs_translation? is true for an untranslated quote" do
    assert @testimonial.needs_translation?
  end

  test "needs_translation? is false once an original is stored" do
    @testimonial.update_columns(quote_original: "Ha trasformato il mio modo di sviluppare", quote_language: "it")
    assert_not @testimonial.reload.needs_translation?
    assert @testimonial.translated?
  end

  test "needs_translation? is false for a blank quote" do
    @testimonial.update_columns(quote: nil)
    assert_not @testimonial.reload.needs_translation?
  end

  test "a translated quote longer than the authoring cap is stored in full" do
    long = "E" * 900
    @testimonial.system_generated = true
    @testimonial.quote = long

    assert @testimonial.valid?, @testimonial.errors.full_messages.to_sentence
    @testimonial.save!
    assert_equal 900, @testimonial.reload.quote.length
  end

  test "a user-submitted quote over the cap is rejected, not trimmed" do
    t = Testimonial.new(user: users(:user_no_testimonial), quote: "R" * 400)

    assert_not t.valid?
    assert t.errors[:quote].any? { |e| e.include?("too long") }
    assert_equal 400, t.quote.length, "the quote must never be silently shortened"
  end
end
