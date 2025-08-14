class RemoveImageBlurDataFromPosts < ActiveRecord::Migration[8.0]
  def change
    remove_column :posts, :image_blur_data, :text
  end
end
