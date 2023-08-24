class AddSrgIdAndVulnIdAndLegacyIdsToBaseRules < ActiveRecord::Migration[6.1]
  def change
    add_column :base_rules, :srg_id, :string
    add_column :base_rules, :vuln_id, :string
    add_column :base_rules, :legacy_ids, :string
  end
end
