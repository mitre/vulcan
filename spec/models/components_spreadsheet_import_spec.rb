# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component do
  include_context 'components model base setup'

  context 'spreadsheet import header aliases (Postel\'s Law)' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    # Requirement: Users should be able to export a STIG/SRG CSV from Vulcan's benchmark viewer
    # and import it as a Component spreadsheet without manually renaming headers.
    # The import should accept both standard DISA headers AND benchmark export headers.

    let(:srg_rules) { components_srg.srg_rules.order(:version) }
    let(:first_srg_rule) { srg_rules.first }
    let(:second_srg_rule) { srg_rules.second }

    # Common test data values
    let(:test_severity) { 'CAT II' }
    let(:test_title) { 'Test requirement title' }
    let(:test_vuln_discussion) { 'Test vuln discussion' }
    let(:test_status) { 'Not Yet Determined' }
    let(:test_check_content) { 'Test check content' }
    let(:test_fix_text) { 'Test fix text' }
    let(:test_prefix) { 'TEST-01' }
    let(:header_artifact_description) { 'Artifact Description' }
    let(:header_status_justification) { 'Status Justification' }
    let(:header_srg_id) { 'SRG ID' }
    let(:header_stig_id) { 'STIG ID' }
    let(:header_fix_text) { 'Fix Text' }
    let(:header_check_content) { 'Check Content' }

    # Helper: create a CSV tempfile with given headers and rows
    def create_csv_file(headers, rows)
      file = Tempfile.new(['import_test', '.csv'])
      CSV.open(file.path, 'w') do |csv|
        csv << headers
        rows.each { |row| csv << row }
      end
      file.path
    end

    # Build row data that works for all SRG rules in the fixture.
    # Uses real SRG IDs from the GPOS SRG fixture.
    def build_all_srg_rows_disa(srg_rules_list, prefix)
      srg_rules_list.map.with_index(1) do |srg_rule, idx|
        stig_id = "#{prefix}-#{format('%06d', idx)}"
        [
          srg_rule.version,           # SRGID
          stig_id,                    # STIGID
          test_severity,              # Severity
          test_title,                 # Requirement
          test_vuln_discussion,       # VulDiscussion
          test_status,                # Status
          test_check_content,         # Check
          test_fix_text,              # Fix
          '',                         # Status Justification
          ''                          # Artifact Description
        ]
      end
    end

    def build_all_srg_rows_benchmark(srg_rules_list, prefix)
      srg_rules_list.map.with_index(1) do |srg_rule, idx|
        stig_id = "#{prefix}-#{format('%06d', idx)}"
        [
          srg_rule.version,           # SRG ID
          stig_id,                    # STIG ID
          test_severity,              # Severity
          test_title,                 # Title
          test_vuln_discussion,       # Description
          test_status,                # Status
          test_check_content,         # Check Content
          test_fix_text,              # Fix Text
          '',                         # Status Justification
          '',                         # Artifact Description
          ''                          # Mitigations
        ]
      end
    end

    it 'imports successfully with standard DISA headers (backwards compatibility)' do
      disa_headers = %w[SRGID STIGID Severity Requirement VulDiscussion Status Check Fix] +
                     [header_status_justification, header_artifact_description]
      rows = build_all_srg_rows_disa(srg_rules, test_prefix)

      csv_path = create_csv_file(disa_headers, rows)
      component = Component.new(project: components_project, based_on: components_srg)
      component.from_spreadsheet(csv_path)

      expect(component.errors.full_messages).to be_empty
      expect(component.rules.size).to eq(srg_rules.size)
      expect(component.rules.first.title).to eq(test_title)
    end

    it 'imports successfully with benchmark export headers (Title, Description, STIG ID, etc.)' do
      # These are the headers produced by BENCHMARK_CSV_COLUMNS export
      benchmark_headers = [header_srg_id, header_stig_id, 'Severity', 'Title', 'Description',
                           'Status', header_check_content, header_fix_text,
                           header_status_justification, header_artifact_description, 'Mitigations']
      rows = build_all_srg_rows_benchmark(srg_rules, test_prefix)

      csv_path = create_csv_file(benchmark_headers, rows)
      component = Component.new(project: components_project, based_on: components_srg)
      component.from_spreadsheet(csv_path)

      expect(component.errors.full_messages).to be_empty
      expect(component.rules.size).to eq(srg_rules.size)
      # Verify field mapping worked correctly
      expect(component.rules.first.title).to eq(test_title)
    end

    it 'maps "Description" header to vuln_discussion field' do
      benchmark_headers = [header_srg_id, header_stig_id, 'Severity', 'Title', 'Description',
                           'Status', header_check_content, header_fix_text,
                           header_status_justification, header_artifact_description, 'Mitigations']
      rows = build_all_srg_rows_benchmark(srg_rules, test_prefix)

      csv_path = create_csv_file(benchmark_headers, rows)
      component = Component.new(project: components_project, based_on: components_srg)
      component.from_spreadsheet(csv_path)

      expect(component.errors.full_messages).to be_empty
      first_rule = component.rules.first
      expect(first_rule.disa_rule_descriptions.first.vuln_discussion).to eq(test_vuln_discussion)
    end

    it 'maps "Check Content" header to check field' do
      benchmark_headers = [header_srg_id, header_stig_id, 'Severity', 'Title', 'Description',
                           'Status', header_check_content, header_fix_text,
                           header_status_justification, header_artifact_description, 'Mitigations']
      rows = build_all_srg_rows_benchmark(srg_rules, test_prefix)

      csv_path = create_csv_file(benchmark_headers, rows)
      component = Component.new(project: components_project, based_on: components_srg)
      component.from_spreadsheet(csv_path)

      expect(component.errors.full_messages).to be_empty
      first_rule = component.rules.first
      expect(first_rule.checks.first.content).to eq(test_check_content)
    end

    it 'maps "Mitigations" header to mitigation field' do
      benchmark_headers = [header_srg_id, header_stig_id, 'Severity', 'Title', 'Description',
                           'Status', header_check_content, header_fix_text,
                           header_status_justification, header_artifact_description, 'Mitigations']
      rows = srg_rules.map.with_index(1) do |srg_rule, idx|
        stig_id = "#{test_prefix}-#{format('%06d', idx)}"
        [
          srg_rule.version, stig_id, test_severity, 'title', 'discussion',
          test_status, 'check', 'fix', '', '', 'Test mitigation text'
        ]
      end

      csv_path = create_csv_file(benchmark_headers, rows)
      component = Component.new(project: components_project, based_on: components_srg)
      component.from_spreadsheet(csv_path)

      expect(component.errors.full_messages).to be_empty
      first_rule = component.rules.first
      expect(first_rule.disa_rule_descriptions.first.mitigations).to eq('Test mitigation text')
    end

    it 'maps "Fix Text" header to fixtext field' do
      benchmark_headers = [header_srg_id, header_stig_id, 'Severity', 'Title', 'Description',
                           'Status', header_check_content, header_fix_text,
                           header_status_justification, header_artifact_description, 'Mitigations']
      rows = build_all_srg_rows_benchmark(srg_rules, test_prefix)

      csv_path = create_csv_file(benchmark_headers, rows)
      component = Component.new(project: components_project, based_on: components_srg)
      component.from_spreadsheet(csv_path)

      expect(component.errors.full_messages).to be_empty
      first_rule = component.rules.first
      expect(first_rule.fixtext).to eq(test_fix_text)
    end
  end
end
