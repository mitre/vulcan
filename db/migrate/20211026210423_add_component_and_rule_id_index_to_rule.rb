class AddComponentAndRuleIdIndexToRule < ActiveRecord::Migration[6.1]
  def change
    add_index :rules, [:rule_id, :component_id], name: 'rule_id_and_component_id', unique: true
  end
end
