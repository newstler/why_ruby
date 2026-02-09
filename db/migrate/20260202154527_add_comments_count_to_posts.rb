class AddCommentsCountToPosts < ActiveRecord::Migration[8.2]
  def change
    add_column :posts, :comments_count, :integer, default: 0, null: false

    # Reset all counter caches
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE posts
          SET comments_count = (
            SELECT COUNT(*)
            FROM comments
            WHERE comments.post_id = posts.id
          )
        SQL
      end
    end
  end
end
