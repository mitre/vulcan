# frozen_string_literal: true

class AddSrgRuleAndSecurityRequirementsGuideToRule < ActiveRecord::Migration[6.1]
  def change
    add_reference :base_rules, :srg_rule, foreign_key: { to_table: :base_rules }
    add_reference :base_rules, :security_requirements_guide, foreign_key: true
  end
end
