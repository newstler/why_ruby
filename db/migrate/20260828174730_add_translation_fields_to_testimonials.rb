class AddTranslationFieldsToTestimonials < ActiveRecord::Migration[8.2]
  def change
    add_column :testimonials, :quote_original, :text
    add_column :testimonials, :quote_language, :string
  end
end
