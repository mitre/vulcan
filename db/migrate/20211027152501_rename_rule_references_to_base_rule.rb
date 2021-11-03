class RenameRuleReferencesToBaseRule < ActiveRecord::Migration[6.1]
  def change
    rename_column :checks, :rule_id, :base_rule_id
    rename_column :disa_rule_descriptions, :rule_id, :base_rule_id
    rename_column :references, :rule_id, :base_rule_id
    rename_column :rule_descriptions, :rule_id, :base_rule_id
  end
end
