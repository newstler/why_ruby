class AllowEmptyQuoteInTestimonials < ActiveRecord::Migration[8.2]
  def change
    # Remove the check constraint that enforces quote length
    remove_check_constraint :testimonials, name: "quote_length_check"

    # Allow NULL for the quote column
    change_column_null :testimonials, :quote, true
  end
end
