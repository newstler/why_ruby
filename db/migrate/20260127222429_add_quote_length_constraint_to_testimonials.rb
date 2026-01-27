class AddQuoteLengthConstraintToTestimonials < ActiveRecord::Migration[8.2]
  def change
    add_check_constraint :testimonials, "length(quote) >= 140 AND length(quote) <= 320", name: "quote_length_check"
  end
end
