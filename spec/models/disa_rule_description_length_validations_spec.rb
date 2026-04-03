# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: Text fields on disa_rule_descriptions must enforce maximum lengths.
# All limits read from Settings.input_limits for configurability.
RSpec.describe DisaRuleDescription do
  describe 'text field length validations' do
    %i[vuln_discussion false_positives false_negatives mitigations
       severity_override_guidance potential_impacts third_party_tools
       mitigation_control responsibility ia_controls poam].each do |field|
      it { is_expected.to validate_length_of(field).is_at_most(Settings.input_limits.long_text).allow_nil }
    end
  end
end
