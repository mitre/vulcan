class CreateRuleSatisfactions < ActiveRecord::Migration[6.1]
  def change
    create_table :rule_satisfactions, id: false do |t|
      t.bigint :base_rule_id
      t.bigint :satisfied_by_base_rule_id
    end

    add_index :rule_satisfactions, [:base_rule_id, :satisfied_by_base_rule_id], unique: true, name: 'index_rule_satisfactions_1'
    add_index :rule_satisfactions, [:satisfied_by_base_rule_id, :base_rule_id], unique: true, name: 'index_rule_satisfactions_2'
  end
end
