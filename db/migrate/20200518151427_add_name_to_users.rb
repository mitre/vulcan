# frozen_string_literal: true

class AddNameToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :name, :string
  end
end
