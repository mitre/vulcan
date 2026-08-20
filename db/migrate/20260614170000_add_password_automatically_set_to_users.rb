# frozen_string_literal: true

class AddPasswordAutomaticallySetToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :password_automatically_set, :boolean, default: false, null: false

    reversible do |dir|
      dir.up do
        User.where.not(provider: nil).update_all(password_automatically_set: true)
      end
    end
  end
end
