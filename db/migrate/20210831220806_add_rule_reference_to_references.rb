# frozen_string_literal: true

class AddRuleReferenceToReferences < ActiveRecord::Migration[6.1]
  def change
    add_column :references, :rule_id, :bigint
  end
end
