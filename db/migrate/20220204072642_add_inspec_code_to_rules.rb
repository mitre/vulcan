class AddInspecCodeToRules < ActiveRecord::Migration[6.1]
  def change
    add_column :base_rules, :inspec_control_body, :text
    add_column :base_rules, :inspec_control_file, :text
  end
end
