# frozen_string_literal: true

# Adds password_salt column for PBKDF2 migration. Existing bcrypt users have NULL salt
# and will be re-hashed with a salt on next login (transparent migration in User model).
class AddPasswordSaltToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :password_salt, :string
  end
end
