# frozen_string_literal: true

class AddProviderUidIndexToUsers < ActiveRecord::Migration[6.1]
  def change
    # Add compound unique index on provider and uid to prevent duplicate provider/uid combinations
    # Only applies when both provider and uid are present (excludes local users)
    add_index :users, %i[provider uid],
              unique: true,
              where: 'provider IS NOT NULL AND uid IS NOT NULL',
              name: 'index_users_on_provider_and_uid'
  end
end
