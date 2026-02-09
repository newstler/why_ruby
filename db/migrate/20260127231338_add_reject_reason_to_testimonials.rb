class AddRejectReasonToTestimonials < ActiveRecord::Migration[8.2]
  def change
    add_column :testimonials, :reject_reason, :string
  end
end
