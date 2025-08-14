class ConvertSuccessStoriesToCategory < ActiveRecord::Migration[8.1]
  def up
    # Create or find the Success Stories category
    success_category = Category.find_or_create_by!(is_success_story: true) do |category|
      category.name = "Success Stories"
      category.description = "Ruby-powered products and companies that have achieved significant scale and success"
      category.position = Category.unscoped.maximum(:position).to_i + 1
    end

    # Update all existing success story posts to use this category
    Post.where(post_type: "success_story").update_all(category_id: success_category.id)
  end

  def down
    # Remove category_id from success story posts
    Post.where(post_type: "success_story").update_all(category_id: nil)

    # Optionally delete the success story category if it exists
    Category.where(is_success_story: true).destroy_all
  end
end
