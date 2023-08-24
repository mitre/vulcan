class AddStigRuleAndStigToRules < ActiveRecord::Migration[6.1]
  def change
    add_reference :base_rules, :stig, foreign_key: true
    add_reference :base_rules, :stig_rule, foreign_key: { to_table: :base_rules }
  end
end
