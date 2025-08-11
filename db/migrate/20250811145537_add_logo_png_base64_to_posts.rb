class AddLogoPngBase64ToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :logo_png_base64, :text
  end
end
