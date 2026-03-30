class RemoveEmailNotNullConstraintFromUsers < ActiveRecord::Migration[8.2]
  def change
    change_column_null :users, :email, true
  end
end
