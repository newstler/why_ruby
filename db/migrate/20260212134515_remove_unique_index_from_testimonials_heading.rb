class RemoveUniqueIndexFromTestimonialsHeading < ActiveRecord::Migration[8.2]
  def change
    remove_index :testimonials, :heading, unique: true
    add_index :testimonials, :heading
  end
end
