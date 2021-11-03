class RenameRuleTableToBaseRule < ActiveRecord::Migration[6.1]
  def change
    rename_table :rules, :base_rules
  end
end
