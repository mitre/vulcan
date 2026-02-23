# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: Text fields on disa_rule_descriptions must enforce maximum lengths.
# vuln_discussion can be lengthy (DISA content), others are shorter metadata.
RSpec.describe DisaRuleDescription do
  describe 'text field length validations' do
    # Long text (10_000)
    %i[vuln_discussion false_positives false_negatives mitigations
       severity_override_guidance potential_impacts third_party_tools
       mitigation_control responsibility ia_controls poam].each do |field|
      it { is_expected.to validate_length_of(field).is_at_most(10_000).allow_nil }
    end
  end
end
