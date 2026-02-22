class AddPasswordSaltToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :password_salt, :string
  end
end
