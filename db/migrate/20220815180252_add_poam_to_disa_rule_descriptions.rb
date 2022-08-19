class AddPoamToDisaRuleDescriptions < ActiveRecord::Migration[6.1]
  def change
    add_column :disa_rule_descriptions, :mitigations_available, :boolean
    add_column :disa_rule_descriptions, :poam_available, :boolean
    add_column :disa_rule_descriptions, :poam, :text
  end
end
