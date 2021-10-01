class AddRuleStatusCountersToProject < ActiveRecord::Migration[6.1]
  def change
    add_column :projects, :in_development_rule_count, :integer, default: 0
    add_column :projects, :under_review_rule_count, :integer, default: 0
    add_column :projects, :locked_rule_count, :integer, default: 0
  end
end
