# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: VendorSubmission mode produces a strict DISA-compliant export
# per the Vendor STIG Process Guide V4R1:
#
# - Exactly 17 columns (Table 8-1) — no Vendor Comments, no Satisfies, no InSpec
# - STIGID left blank (DISA fills during finalization) — Section 4.1.4
# - Check/Fix blank for non-AC statuses — Sections 4.1.11, 4.1.13
# - VulnDiscussion blank for NA — Section 4.1.8
# - Severity blank for NA — Section 4.1.14
# - Mitigation required only for ADNM — Section 4.1.15
# - Artifact Description required only for AIM — Section 4.1.16
# - Status Justification required for AIM, ADNM, NA — Section 4.1.17
# - NYD rules excluded (not a DISA-recognized status)
# - Satisfies text appended to VulnDiscussion (not separate column)
# ==========================================================================
STATUS_AC = 'Applicable - Configurable'
STATUS_AIM = 'Applicable - Inherently Meets'
STATUS_ADNM = 'Applicable - Does Not Meet'
STATUS_NA = 'Not Applicable'
TEST_STIG_ID = 'RHEL-09-001'
TEST_CHECK = 'Verify the setting...'
TEST_FIX = 'Configure the setting...'
TEST_VULN = 'Without this...'
TEST_CAT = 'CAT II'
TEST_TEXT = 'some text'
TEST_ORIGINAL = 'original value'

RSpec.describe Export::Modes::VendorSubmission do
  subject(:mode) { described_class.new }

  describe '#columns' do
    it 'returns exactly 17 column keys (strict DISA template)' do
      expect(mode.columns.size).to eq 17
    end

    it 'does NOT include vendor_comments' do
      expect(mode.columns).not_to include(:vendor_comments)
    end

    it 'does NOT include satisfies' do
      expect(mode.columns).not_to include(:satisfies)
    end

    it 'does NOT include inspec_control_body' do
      expect(mode.columns).not_to include(:inspec_control_body)
    end

    it 'starts with nist_control_family and ends with status_justification' do
      expect(mode.columns.first).to eq :nist_control_family
      expect(mode.columns.last).to eq :status_justification
    end
  end

  describe '#headers' do
    it 'returns exactly 17 headers matching DISA Table 8-1' do
      expect(mode.headers.size).to eq 17
    end

    it 'has same count as columns' do
      expect(mode.headers.size).to eq mode.columns.size
    end

    it 'starts with IA Control and ends with Status Justification' do
      expect(mode.headers.first).to eq 'IA Control'
      expect(mode.headers.last).to eq 'Status Justification'
    end

    it 'does NOT include Vendor Comments' do
      expect(mode.headers).not_to include('Vendor Comments')
    end

    it 'does NOT include Satisfies' do
      expect(mode.headers).not_to include('Satisfies')
    end

    it 'does NOT include InSpec Control Body' do
      expect(mode.headers).not_to include('InSpec Control Body')
    end
  end

  describe '#rule_scope' do
    let_it_be(:component) { create(:component) }

    it 'excludes Not Yet Determined rules' do
      # Ensure at least one NYD rule exists
      component.rules.first.update!(status: 'Not Yet Determined')
      nyd_count = component.rules.where(status: 'Not Yet Determined').count
      all_count = component.rules.count

      scoped = mode.rule_scope(component.rules)
      expect(scoped.count).to eq(all_count - nyd_count)
    end

    it 'includes Applicable - Configurable rules' do
      component.rules.first.update!(status: STATUS_AC)
      scoped = mode.rule_scope(component.rules)
      expect(scoped.where(status: STATUS_AC).count).to be >= 1
    end

    it 'includes Applicable - Inherently Meets rules' do
      component.rules.first.update!(status: STATUS_AIM)
      scoped = mode.rule_scope(component.rules)
      expect(scoped.where(status: STATUS_AIM).count).to be >= 1
    end

    it 'includes Applicable - Does Not Meet rules' do
      component.rules.first.update!(status: STATUS_ADNM)
      scoped = mode.rule_scope(component.rules)
      expect(scoped.where(status: STATUS_ADNM).count).to be >= 1
    end

    it 'includes Not Applicable rules' do
      component.rules.first.update!(status: STATUS_NA)
      scoped = mode.rule_scope(component.rules)
      expect(scoped.where(status: STATUS_NA).count).to be >= 1
    end

    context 'with exclude_satisfied_by option' do
      subject(:mode) { described_class.new(exclude_satisfied_by: true) }

      it 'excludes rules that have satisfied_by relationships' do
        rules = component.rules.order(:id)
        parent_rule = rules.first
        child_rule = rules.second
        normal_rule = rules.third

        # Set all to AC so they pass the NYD filter
        [parent_rule, child_rule, normal_rule].each { |r| r.update!(status: STATUS_AC) }
        RuleSatisfaction.create!(rule_id: parent_rule.id, satisfied_by_rule_id: child_rule.id)

        result = mode.rule_scope(component.rules)
        expect(result).to include(normal_rule)
        expect(result).to include(child_rule)
        expect(result).not_to include(parent_rule)
      end

      it 'still excludes NYD rules' do
        rules = component.rules.order(:id)
        rules.first.update!(status: 'Not Yet Determined')
        rules.second.update!(status: STATUS_AC)

        result = mode.rule_scope(component.rules)
        expect(result.where(status: 'Not Yet Determined')).to be_empty
      end
    end
  end

  # ==========================================================================
  # Field-blanking requirements per DISA Process Guide V4R1
  # See docs/disa-process/field-requirements.md for full matrix
  # ==========================================================================
  describe '#transform_value' do
    # Build a minimal exportable_rule double for each status
    let(:ac_rule) { instance_double(Export::ExportableRule, status: STATUS_AC) }
    let(:aim_rule) { instance_double(Export::ExportableRule, status: STATUS_AIM) }
    let(:adnm_rule) { instance_double(Export::ExportableRule, status: STATUS_ADNM) }
    let(:na_rule) { instance_double(Export::ExportableRule, status: STATUS_NA) }

    # --- STIGID: blank for ALL statuses (Section 4.1.4) ---
    context 'stig_id (DISA fills during finalization)' do
      it 'blanks stig_id for AC' do
        expect(mode.transform_value(:stig_id, TEST_STIG_ID, ac_rule)).to be_nil
      end

      it 'blanks stig_id for AIM' do
        expect(mode.transform_value(:stig_id, TEST_STIG_ID, aim_rule)).to be_nil
      end

      it 'blanks stig_id for ADNM' do
        expect(mode.transform_value(:stig_id, TEST_STIG_ID, adnm_rule)).to be_nil
      end

      it 'blanks stig_id for NA' do
        expect(mode.transform_value(:stig_id, TEST_STIG_ID, na_rule)).to be_nil
      end
    end

    # --- Check Content: required for AC only (Section 4.1.11) ---
    context 'check_content' do
      it 'keeps check_content for AC' do
        expect(mode.transform_value(:check_content, TEST_CHECK, ac_rule)).to eq TEST_CHECK
      end

      it 'blanks check_content for AIM' do
        expect(mode.transform_value(:check_content, TEST_CHECK, aim_rule)).to be_nil
      end

      it 'blanks check_content for ADNM' do
        expect(mode.transform_value(:check_content, TEST_CHECK, adnm_rule)).to be_nil
      end

      it 'blanks check_content for NA' do
        expect(mode.transform_value(:check_content, TEST_CHECK, na_rule)).to be_nil
      end
    end

    # --- Fix Text: required for AC only (Section 4.1.13) ---
    context 'fixtext' do
      it 'keeps fixtext for AC' do
        expect(mode.transform_value(:fixtext, TEST_FIX, ac_rule)).to eq TEST_FIX
      end

      it 'blanks fixtext for AIM' do
        expect(mode.transform_value(:fixtext, TEST_FIX, aim_rule)).to be_nil
      end

      it 'blanks fixtext for ADNM' do
        expect(mode.transform_value(:fixtext, TEST_FIX, adnm_rule)).to be_nil
      end

      it 'blanks fixtext for NA' do
        expect(mode.transform_value(:fixtext, TEST_FIX, na_rule)).to be_nil
      end
    end

    # --- VulnDiscussion: blank for NA (Section 4.1.8) ---
    context 'vuln_discussion' do
      it 'keeps vuln_discussion for AC' do
        expect(mode.transform_value(:vuln_discussion, TEST_VULN, ac_rule)).to eq TEST_VULN
      end

      it 'keeps vuln_discussion for AIM' do
        expect(mode.transform_value(:vuln_discussion, TEST_VULN, aim_rule)).to eq TEST_VULN
      end

      it 'keeps vuln_discussion for ADNM' do
        expect(mode.transform_value(:vuln_discussion, TEST_VULN, adnm_rule)).to eq TEST_VULN
      end

      it 'blanks vuln_discussion for NA' do
        expect(mode.transform_value(:vuln_discussion, TEST_VULN, na_rule)).to be_nil
      end
    end

    # --- Severity: blank for NA (Section 4.1.14) ---
    context 'severity' do
      it 'keeps severity for AC' do
        expect(mode.transform_value(:severity, TEST_CAT, ac_rule)).to eq TEST_CAT
      end

      it 'keeps severity for AIM' do
        expect(mode.transform_value(:severity, TEST_CAT, aim_rule)).to eq TEST_CAT
      end

      it 'keeps severity for ADNM' do
        expect(mode.transform_value(:severity, TEST_CAT, adnm_rule)).to eq TEST_CAT
      end

      it 'blanks severity for NA' do
        expect(mode.transform_value(:severity, TEST_CAT, na_rule)).to be_nil
      end
    end

    # --- Mitigation: required for ADNM only (Section 4.1.15) ---
    context 'mitigation' do
      it 'blanks mitigation for AC' do
        expect(mode.transform_value(:mitigation, TEST_TEXT, ac_rule)).to be_nil
      end

      it 'blanks mitigation for AIM' do
        expect(mode.transform_value(:mitigation, TEST_TEXT, aim_rule)).to be_nil
      end

      it 'keeps mitigation for ADNM' do
        expect(mode.transform_value(:mitigation, 'Mitigated by OS STIG', adnm_rule)).to eq 'Mitigated by OS STIG'
      end

      it 'blanks mitigation for NA' do
        expect(mode.transform_value(:mitigation, TEST_TEXT, na_rule)).to be_nil
      end
    end

    # --- Artifact Description: required for AIM only (Section 4.1.16) ---
    context 'artifact_description' do
      it 'blanks artifact_description for AC' do
        expect(mode.transform_value(:artifact_description, TEST_TEXT, ac_rule)).to be_nil
      end

      it 'keeps artifact_description for AIM' do
        expect(mode.transform_value(:artifact_description, 'Published manual ref', aim_rule)).to eq 'Published manual ref'
      end

      it 'blanks artifact_description for ADNM' do
        expect(mode.transform_value(:artifact_description, TEST_TEXT, adnm_rule)).to be_nil
      end

      it 'blanks artifact_description for NA' do
        expect(mode.transform_value(:artifact_description, TEST_TEXT, na_rule)).to be_nil
      end
    end

    # --- Status Justification: required for AIM, ADNM, NA (Section 4.1.17) ---
    context 'status_justification' do
      it 'blanks status_justification for AC' do
        expect(mode.transform_value(:status_justification, TEST_TEXT, ac_rule)).to be_nil
      end

      it 'keeps status_justification for AIM' do
        expect(mode.transform_value(:status_justification, 'Inherently meets because...', aim_rule)).to eq 'Inherently meets because...'
      end

      it 'keeps status_justification for ADNM' do
        expect(mode.transform_value(:status_justification, 'Cannot meet because...', adnm_rule)).to eq 'Cannot meet because...'
      end

      it 'keeps status_justification for NA' do
        expect(mode.transform_value(:status_justification, 'Not applicable because...', na_rule)).to eq 'Not applicable because...'
      end
    end

    # --- Pass-through columns: values unmodified regardless of status ---
    context 'pass-through columns' do
      %i[nist_control_family ident srg_id srg_title title srg_vuln_discussion
         status srg_check srg_fix].each do |column|
        it "passes through #{column} unchanged for any status" do
          expect(mode.transform_value(column, TEST_ORIGINAL, ac_rule)).to eq TEST_ORIGINAL
          expect(mode.transform_value(column, TEST_ORIGINAL, na_rule)).to eq TEST_ORIGINAL
        end
      end
    end
  end

  describe '#eager_load_associations' do
    it 'returns associations needed for DISA export' do
      assocs = mode.eager_load_associations
      expect(assocs).to be_an(Array)
      expect(assocs).to include(:disa_rule_descriptions)
      expect(assocs).to include(:checks)
      expect(assocs).to include(:satisfies)
      expect(assocs).to include(:satisfied_by)
    end
  end
end
