class AddPerTaskAiModelsToSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :settings, :summary_model, :string
    add_column :settings, :testimonial_model, :string
    add_column :settings, :validation_model, :string
    add_column :settings, :translation_model, :string
  end
end
