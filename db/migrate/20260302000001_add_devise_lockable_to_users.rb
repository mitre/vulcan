# frozen_string_literal: true

# Add Devise Lockable columns for existing deployments.
# schema.rb already has these columns, but there was no migration file.
# Uses if_not_exists / if_exists guards so it's safe to run on both
# fresh databases and existing ones that loaded schema.rb directly.
class AddDeviseLockableToUsers < ActiveRecord::Migration[8.0]
  def up
    unless column_exists?(:users, :failed_attempts)
      add_column :users, :failed_attempts, :integer, default: 0, null: false
    end

    unless column_exists?(:users, :unlock_token)
      add_column :users, :unlock_token, :string
    end

    unless column_exists?(:users, :locked_at)
      add_column :users, :locked_at, :datetime
    end

    unless index_exists?(:users, :unlock_token, name: 'index_users_on_unlock_token')
      add_index :users, :unlock_token, unique: true, name: 'index_users_on_unlock_token'
    end
  end

  def down
    remove_index :users, name: 'index_users_on_unlock_token', if_exists: true
    remove_column :users, :locked_at, if_exists: true
    remove_column :users, :unlock_token, if_exists: true
    remove_column :users, :failed_attempts, if_exists: true
  end
end
