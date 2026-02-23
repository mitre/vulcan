# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: Text fields on base_rules must enforce maximum lengths to prevent
# abuse via oversized input. These limits protect the database and downstream
# consumers (Excel export, PDF generation, API responses).
#
# Limits based on realistic STIG content maximums with headroom:
#   Short strings (IDs, names):   255 chars
#   Medium text (title):         1_000 chars
#   Long text (descriptions):   10_000 chars
#   Very long (InSpec bodies):  50_000 chars
RSpec.describe BaseRule do
  describe 'text field length validations' do
    # Short string fields (255)
    # rule_severity excluded: constrained by inclusion validation (low/medium/high)
    %i[rule_id rule_weight version ident_system
       fixtext_fixref fix_id srg_id vuln_id legacy_ids].each do |field|
      it { is_expected.to validate_length_of(field).is_at_most(255).allow_nil }
    end

    # ident is a comma-joined CCI list — real STIG data can have 310+ chars
    it { is_expected.to validate_length_of(:ident).is_at_most(2_048).allow_nil }

    # Medium text (1_000)
    %i[title status_justification].each do |field|
      it { is_expected.to validate_length_of(field).is_at_most(1_000).allow_nil }
    end

    # Long text (10_000)
    %i[fixtext artifact_description vendor_comments].each do |field|
      it { is_expected.to validate_length_of(field).is_at_most(10_000).allow_nil }
    end

    # Very long text (50_000)
    %i[inspec_control_body inspec_control_file].each do |field|
      it { is_expected.to validate_length_of(field).is_at_most(50_000).allow_nil }
    end
  end
end
