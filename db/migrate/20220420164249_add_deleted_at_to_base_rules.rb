class AddDeletedAtToBaseRules < ActiveRecord::Migration[6.1]
  def change
    add_column :base_rules, :deleted_at, :datetime
    add_index :base_rules, :deleted_at
  end
end
