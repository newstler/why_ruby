class AddSuccessStoryFieldsToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :post_type, :string, default: 'article', null: false
    add_column :posts, :logo_svg, :text

    # Update existing posts to have the correct post_type
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE posts#{' '}
          SET post_type = CASE#{' '}
            WHEN url IS NOT NULL AND url != '' THEN 'link'
            ELSE 'article'
          END
        SQL
      end
    end

    add_index :posts, :post_type
  end
end
