class AddUniqueIndexForRuleIdAndProjectId < ActiveRecord::Migration[6.1]
  def change
    add_index :rules, [:rule_id, :project_id], unique: true, name: "rules_rule_id_project_id_index"
  end
end
