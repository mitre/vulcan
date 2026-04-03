# frozen_string_literal: true

class AddLockedFieldsToBaseRules < ActiveRecord::Migration[8.0]
  def change
    add_column :base_rules, :locked_fields, :jsonb, default: {}
  end
end
