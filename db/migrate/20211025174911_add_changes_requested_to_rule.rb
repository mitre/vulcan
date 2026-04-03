# frozen_string_literal: true

class AddChangesRequestedToRule < ActiveRecord::Migration[6.1]
  def change
    add_column :rules, :changes_requested, :boolean, default: false
  end
end
