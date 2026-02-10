# frozen_string_literal: true

class AddSeverityCountIndexesToBaseRules < ActiveRecord::Migration[8.0]
  def change
    # Composite index for STIG severity counts
    # Optimizes: WHERE stig_id = X AND type = 'StigRule' AND rule_severity = Y
    add_index :base_rules, %i[stig_id type rule_severity],
              name: 'index_base_rules_on_stig_type_severity'

    # Composite index for SRG severity counts
    # Optimizes: WHERE security_requirements_guide_id = X AND type = 'SrgRule' AND rule_severity = Y
    add_index :base_rules, %i[security_requirements_guide_id type rule_severity],
              name: 'index_base_rules_on_srg_type_severity'

    # Composite index for Component severity counts (with soft delete support)
    # Optimizes: WHERE component_id = X AND deleted_at IS NULL AND rule_severity = Y
    add_index :base_rules, %i[component_id deleted_at rule_severity],
              name: 'index_base_rules_on_component_deleted_severity'
  end
end
