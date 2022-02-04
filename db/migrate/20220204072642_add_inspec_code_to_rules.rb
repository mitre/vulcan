class AddInspecCodeToRules < ActiveRecord::Migration[6.1]
  def change
    add_column :base_rules, :code, :text
    add_column :base_rules, :inspec, :text
  end
end
