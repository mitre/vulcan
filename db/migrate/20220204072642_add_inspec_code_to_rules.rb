class AddInspecCodeToRules < ActiveRecord::Migration[6.1]
  def up
    add_column :base_rules, :inspec_control_body, :text
    add_column :base_rules, :inspec_control_file, :text

    ActiveRecord::Base.transaction do
      Rule.unscoped.each do |rule|
        # Trigger update_inspec_code callback
        rule.save
      end
    end
  end

  def down
    remove_column :base_rules, :inspec_control_body, :text
    remove_column :base_rules, :inspec_control_file, :text
  end
end
