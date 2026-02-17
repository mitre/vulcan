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
    let(:component) { create(:component) }

    it 'excludes Not Yet Determined rules' do
      # Ensure at least one NYD rule exists
      component.rules.first.update!(status: 'Not Yet Determined')
      nyd_count = component.rules.where(status: 'Not Yet Determined').count
      all_count = component.rules.count

      scoped = mode.rule_scope(component.rules)
      expect(scoped.count).to eq(all_count - nyd_count)
    end

    it 'includes Applicable - Configurable rules' do
      component.rules.first.update!(status: 'Applicable - Configurable')
      scoped = mode.rule_scope(component.rules)
      expect(scoped.where(status: 'Applicable - Configurable').count).to be >= 1
    end

    it 'includes Applicable - Inherently Meets rules' do
      component.rules.first.update!(status: 'Applicable - Inherently Meets')
      scoped = mode.rule_scope(component.rules)
      expect(scoped.where(status: 'Applicable - Inherently Meets').count).to be >= 1
    end

    it 'includes Applicable - Does Not Meet rules' do
      component.rules.first.update!(status: 'Applicable - Does Not Meet')
      scoped = mode.rule_scope(component.rules)
      expect(scoped.where(status: 'Applicable - Does Not Meet').count).to be >= 1
    end

    it 'includes Not Applicable rules' do
      component.rules.first.update!(status: 'Not Applicable')
      scoped = mode.rule_scope(component.rules)
      expect(scoped.where(status: 'Not Applicable').count).to be >= 1
    end
  end

  # ==========================================================================
  # Field-blanking requirements per DISA Process Guide V4R1
  # See docs/disa-process/field-requirements.md for full matrix
  # ==========================================================================
  describe '#transform_value' do
    # Build a minimal exportable_rule double for each status
    let(:ac_rule) { instance_double(Export::ExportableRule, status: 'Applicable - Configurable') }
    let(:aim_rule) { instance_double(Export::ExportableRule, status: 'Applicable - Inherently Meets') }
    let(:adnm_rule) { instance_double(Export::ExportableRule, status: 'Applicable - Does Not Meet') }
    let(:na_rule) { instance_double(Export::ExportableRule, status: 'Not Applicable') }

    # --- STIGID: blank for ALL statuses (Section 4.1.4) ---
    context 'stig_id (DISA fills during finalization)' do
      it 'blanks stig_id for AC' do
        expect(mode.transform_value(:stig_id, 'RHEL-09-001', ac_rule)).to be_nil
      end

      it 'blanks stig_id for AIM' do
        expect(mode.transform_value(:stig_id, 'RHEL-09-001', aim_rule)).to be_nil
      end

      it 'blanks stig_id for ADNM' do
        expect(mode.transform_value(:stig_id, 'RHEL-09-001', adnm_rule)).to be_nil
      end

      it 'blanks stig_id for NA' do
        expect(mode.transform_value(:stig_id, 'RHEL-09-001', na_rule)).to be_nil
      end
    end

    # --- Check Content: required for AC only (Section 4.1.11) ---
    context 'check_content' do
      it 'keeps check_content for AC' do
        expect(mode.transform_value(:check_content, 'Verify the setting...', ac_rule)).to eq 'Verify the setting...'
      end

      it 'blanks check_content for AIM' do
        expect(mode.transform_value(:check_content, 'Verify the setting...', aim_rule)).to be_nil
      end

      it 'blanks check_content for ADNM' do
        expect(mode.transform_value(:check_content, 'Verify the setting...', adnm_rule)).to be_nil
      end

      it 'blanks check_content for NA' do
        expect(mode.transform_value(:check_content, 'Verify the setting...', na_rule)).to be_nil
      end
    end

    # --- Fix Text: required for AC only (Section 4.1.13) ---
    context 'fixtext' do
      it 'keeps fixtext for AC' do
        expect(mode.transform_value(:fixtext, 'Configure the setting...', ac_rule)).to eq 'Configure the setting...'
      end

      it 'blanks fixtext for AIM' do
        expect(mode.transform_value(:fixtext, 'Configure the setting...', aim_rule)).to be_nil
      end

      it 'blanks fixtext for ADNM' do
        expect(mode.transform_value(:fixtext, 'Configure the setting...', adnm_rule)).to be_nil
      end

      it 'blanks fixtext for NA' do
        expect(mode.transform_value(:fixtext, 'Configure the setting...', na_rule)).to be_nil
      end
    end

    # --- VulnDiscussion: blank for NA (Section 4.1.8) ---
    context 'vuln_discussion' do
      it 'keeps vuln_discussion for AC' do
        expect(mode.transform_value(:vuln_discussion, 'Without this...', ac_rule)).to eq 'Without this...'
      end

      it 'keeps vuln_discussion for AIM' do
        expect(mode.transform_value(:vuln_discussion, 'Without this...', aim_rule)).to eq 'Without this...'
      end

      it 'keeps vuln_discussion for ADNM' do
        expect(mode.transform_value(:vuln_discussion, 'Without this...', adnm_rule)).to eq 'Without this...'
      end

      it 'blanks vuln_discussion for NA' do
        expect(mode.transform_value(:vuln_discussion, 'Without this...', na_rule)).to be_nil
      end
    end

    # --- Severity: blank for NA (Section 4.1.14) ---
    context 'severity' do
      it 'keeps severity for AC' do
        expect(mode.transform_value(:severity, 'CAT II', ac_rule)).to eq 'CAT II'
      end

      it 'keeps severity for AIM' do
        expect(mode.transform_value(:severity, 'CAT II', aim_rule)).to eq 'CAT II'
      end

      it 'keeps severity for ADNM' do
        expect(mode.transform_value(:severity, 'CAT II', adnm_rule)).to eq 'CAT II'
      end

      it 'blanks severity for NA' do
        expect(mode.transform_value(:severity, 'CAT II', na_rule)).to be_nil
      end
    end

    # --- Mitigation: required for ADNM only (Section 4.1.15) ---
    context 'mitigation' do
      it 'blanks mitigation for AC' do
        expect(mode.transform_value(:mitigation, 'some text', ac_rule)).to be_nil
      end

      it 'blanks mitigation for AIM' do
        expect(mode.transform_value(:mitigation, 'some text', aim_rule)).to be_nil
      end

      it 'keeps mitigation for ADNM' do
        expect(mode.transform_value(:mitigation, 'Mitigated by OS STIG', adnm_rule)).to eq 'Mitigated by OS STIG'
      end

      it 'blanks mitigation for NA' do
        expect(mode.transform_value(:mitigation, 'some text', na_rule)).to be_nil
      end
    end

    # --- Artifact Description: required for AIM only (Section 4.1.16) ---
    context 'artifact_description' do
      it 'blanks artifact_description for AC' do
        expect(mode.transform_value(:artifact_description, 'some text', ac_rule)).to be_nil
      end

      it 'keeps artifact_description for AIM' do
        expect(mode.transform_value(:artifact_description, 'Published manual ref', aim_rule)).to eq 'Published manual ref'
      end

      it 'blanks artifact_description for ADNM' do
        expect(mode.transform_value(:artifact_description, 'some text', adnm_rule)).to be_nil
      end

      it 'blanks artifact_description for NA' do
        expect(mode.transform_value(:artifact_description, 'some text', na_rule)).to be_nil
      end
    end

    # --- Status Justification: required for AIM, ADNM, NA (Section 4.1.17) ---
    context 'status_justification' do
      it 'blanks status_justification for AC' do
        expect(mode.transform_value(:status_justification, 'some text', ac_rule)).to be_nil
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
          expect(mode.transform_value(column, 'original value', ac_rule)).to eq 'original value'
          expect(mode.transform_value(column, 'original value', na_rule)).to eq 'original value'
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
