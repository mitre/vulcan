# frozen_string_literal: true

class AddStiToBaseRule < ActiveRecord::Migration[6.1]
  def change
    add_column :base_rules, :type, :string
  end
end
