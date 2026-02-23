# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: Text fields on base_rules must enforce maximum lengths to prevent
# abuse via oversized input. These limits protect the database and downstream
# consumers (Excel export, PDF generation, API responses).
#
# Limits based on realistic STIG content maximums with headroom:
#   Short strings (IDs, names):   255 chars
#   Title:                        Settings.input_limits.title (default 500)
#   Medium text (justification):  Settings.input_limits.medium_text (default 1_000)
#   Long text (descriptions):     Settings.input_limits.long_text (default 10_000)
#   Very long (InSpec bodies):    Settings.input_limits.inspec_code (default 50_000)
#
# All limits are configurable via Settings.input_limits / VULCAN_LIMIT_* env vars.
RSpec.describe BaseRule do
  describe 'text field length validations' do
    # Short string fields
    %i[rule_id rule_weight version ident_system
       fixtext_fixref fix_id srg_id vuln_id legacy_ids].each do |field|
      it { is_expected.to validate_length_of(field).is_at_most(Settings.input_limits.short_string).allow_nil }
    end

    # ident is a comma-joined CCI list — real STIG data can have 310+ chars
    it { is_expected.to validate_length_of(:ident).is_at_most(Settings.input_limits.ident).allow_nil }

    # Title
    it { is_expected.to validate_length_of(:title).is_at_most(Settings.input_limits.title).allow_nil }

    # Medium text
    it { is_expected.to validate_length_of(:status_justification).is_at_most(Settings.input_limits.medium_text).allow_nil }

    # Long text
    %i[fixtext artifact_description vendor_comments].each do |field|
      it { is_expected.to validate_length_of(field).is_at_most(Settings.input_limits.long_text).allow_nil }
    end

    # Very long text (InSpec code)
    %i[inspec_control_body inspec_control_file].each do |field|
      it { is_expected.to validate_length_of(field).is_at_most(Settings.input_limits.inspec_code).allow_nil }
    end
  end
end
