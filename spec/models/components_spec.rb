# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component, type: :model do
  before do
    srg_xml = Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read
    parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
    @srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    @srg.xml = srg_xml
    @srg.save!

    @p1 = Project.create!(name: 'Photon OS 3')
    @p1_c1 = Component.create!(project: @p1, version: 'Photon OS 3 V1R1', prefix: 'PHOS-03', based_on: @srg)
  end

  context 'component release' do
    it 'onlies allow release when all rules are locked' do
      expect(@p1_c1.valid?).to be(true)
      @p1_c1.released = true
      expect(@p1_c1.valid?).to be(false)
      expect(@p1_c1.errors[:base]).to include('Cannot release a component that contains rules that are not yet locked')
    end

    it 'onlies allow depending on a released component' do
      p1_c2 = Component.new(project: @p1, version: 'Photon OS 3 V1R2', prefix: 'PHOS-03', based_on: @srg,
                            component_id: @p1_c1.id)
      expect(p1_c2.valid?).to be(false)
      expect(p1_c2.errors[:base]).to include('Cannot overlay a component that has not been released')

      # release the component
      @p1_c1.rules.update(locked: true)
      @p1_c1.update(released: true)
      p1_c2.component.reload
      expect(p1_c2.valid?).to be(true)
    end

    it 'blocks a component from becoming unreleased' do
      @p1_c1.rules.update(locked: true)
      @p1_c1.released = true
      expect(@p1_c1.valid?).to be(true)
      @p1_c1.save

      @p1_c1.released = false
      expect(@p1_c1.valid?).to be(false)
      expect(@p1_c1.errors[:base]).to include('Cannot unrelease a released component')
    end
  end

  context 'component_id validation' do
    it 'does not allow component to overlay itself' do
      expect(@p1_c1.valid?).to be(true)
      @p1_c1.component_id = @p1_c1.id
      expect(@p1_c1.valid?).to be(false)
      expect(@p1_c1.errors[:component_id]).to include('cannot overlay itself')
    end
  end

  context 'prefix validation' do
    it 'is not nil or blank' do
      expect(@p1_c1.valid?).to be(true)

      @p1_c1.prefix = nil
      expect(@p1_c1.valid?).to be(false)

      @p1_c1.prefix = ''
      expect(@p1_c1.valid?).to be(false)

      @p1_c1.prefix = '      '
      expect(@p1_c1.valid?).to be(false)
    end

    it 'validates format' do
      expect(@p1_c1.valid?).to be(true)

      @p1_c1.prefix = '1111-AA'
      expect(@p1_c1.valid?).to be(true)

      @p1_c1.prefix = 'AAAA00'
      expect(@p1_c1.valid?).to be(false)

      @p1_c1.prefix = 'AAA1-00'
      expect(@p1_c1.valid?).to be(true)

      @p1_c1.prefix = ' AAAA-00 '
      expect(@p1_c1.valid?).to be(false)
    end
  end

  context 'component creation' do
    it 'can duplicate a component under the same project' do
      @p1_c1.rules.update(locked: true)
      @p1_c1.reload
      @p1_c1.update(released: true)

      p1_c2 = @p1_c1.duplicate(new_name: 'Photon OS 3', new_version: 1, new_release: 2, new_title: 'title',
                               new_description: 'desc')
      # should have the same number of rules
      expect(@p1_c1.rules.size).to eq(p1_c2.rules.size)
      # should still belong to the same SRG
      expect(@p1_c1.security_requirements_guide_id).to eq(p1_c2.security_requirements_guide_id)
      # should still belong to the same project
      expect(@p1_c1.project_id).to eq(p1_c2.project_id)
      # should not be released
      expect(p1_c2.released).to be(false)
      # should have the new name
      expect(p1_c2.name).to eq('Photon OS 3')
      # should have the new version
      expect(p1_c2.version).to eq(1)
      # should have the new release
      expect(p1_c2.release).to eq(2)
      # should have the new title
      expect(p1_c2.title).to eq('title')
      # should have the new description
      expect(p1_c2.description).to eq('desc')
    end

    it 'can create a new component from a base SRG' do
      # The creation of p1_c1 in the setup should alread have these rules created
      @p1_c1.reload
      expect(@p1_c1.rules.size).to eq(@srg.srg_rules.size)
    end
  end

  context 'spreadsheet import header aliases (Postel\'s Law)' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    # Requirement: Users should be able to export a STIG/SRG CSV from Vulcan's benchmark viewer
    # and import it as a Component spreadsheet without manually renaming headers.
    # The import should accept both standard DISA headers AND benchmark export headers.

    let(:srg_rules) { @srg.srg_rules.order(:version) }
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
      component = Component.new(project: @p1, based_on: @srg)
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
      component = Component.new(project: @p1, based_on: @srg)
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
      component = Component.new(project: @p1, based_on: @srg)
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
      component = Component.new(project: @p1, based_on: @srg)
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
      component = Component.new(project: @p1, based_on: @srg)
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
      component = Component.new(project: @p1, based_on: @srg)
      component.from_spreadsheet(csv_path)

      expect(component.errors.full_messages).to be_empty
      first_rule = component.rules.first
      expect(first_rule.fixtext).to eq(test_fix_text)
    end
  end

  context 'create rule satisfaction' do
    it 'correctly establishes rule satisfactions relation when a rule is satisfied by more than one other rules' do
      pref = @p1_c1.prefix
      rule_id_one = @p1_c1.rules.first.rule_id
      rule_id_two = @p1_c1.rules.second.rule_id
      sb = @p1_c1.rules.last
      sb.vendor_comments = "Satisfied By: #{pref}-#{rule_id_one}, #{pref}-#{rule_id_two}"
      sb.save!
      @p1_c1.create_rule_satisfactions
      expect(@p1_c1.rules.last.satisfied_by.size).to eq(2)
    end

    it 'correctly establishes rule satisfactions relation when a rule is satisfied by another rule' do
      pref = @p1_c1.prefix
      rule_id_one = @p1_c1.rules.first.rule_id
      sb = @p1_c1.rules.last
      sb.vendor_comments = "Satisfied By: #{pref}-#{rule_id_one}"
      sb.save!
      @p1_c1.create_rule_satisfactions
      expect(@p1_c1.rules.last.satisfied_by.size).to eq(1)
    end

    it 'parses satisfied by list with trailing period' do
      pref = @p1_c1.prefix
      rule_id_one = @p1_c1.rules.first.rule_id
      rule_id_two = @p1_c1.rules.second.rule_id
      sb = @p1_c1.rules.last
      sb.vendor_comments = "Satisfied By: #{pref}-#{rule_id_one}, #{pref}-#{rule_id_two}."
      sb.save!
      @p1_c1.create_rule_satisfactions
      expect(@p1_c1.rules.last.satisfied_by.size).to eq(2)
    end

    it 'parses satisfied by list without trailing period' do
      pref = @p1_c1.prefix
      rule_id_one = @p1_c1.rules.first.rule_id
      rule_id_two = @p1_c1.rules.second.rule_id
      sb = @p1_c1.rules.last
      sb.vendor_comments = "Satisfied By: #{pref}-#{rule_id_one}, #{pref}-#{rule_id_two}"
      sb.save!
      @p1_c1.create_rule_satisfactions
      expect(@p1_c1.rules.last.satisfied_by.size).to eq(2)
    end

    it 'parses satisfied by list with extra whitespace' do
      pref = @p1_c1.prefix
      rule_id_one = @p1_c1.rules.first.rule_id
      sb = @p1_c1.rules.last
      sb.vendor_comments = "Satisfied By: #{pref}-#{rule_id_one}   ."
      sb.save!
      @p1_c1.create_rule_satisfactions
      expect(@p1_c1.rules.last.satisfied_by.size).to eq(1)
    end

    # Postel's Law: Be liberal in what you accept
    # All reasonable variations of "Satisfied By" and "Satisfies" should work

    it 'parses lowercase "satisfied by:"' do
      pref = @p1_c1.prefix
      rule_id_one = @p1_c1.rules.first.rule_id
      sb = @p1_c1.rules.last
      sb.vendor_comments = "satisfied by: #{pref}-#{rule_id_one}."
      sb.save!
      @p1_c1.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(1)
    end

    it 'parses uppercase "SATISFIED BY:"' do
      pref = @p1_c1.prefix
      rule_id_one = @p1_c1.rules.first.rule_id
      sb = @p1_c1.rules.last
      sb.vendor_comments = "SATISFIED BY: #{pref}-#{rule_id_one}."
      sb.save!
      @p1_c1.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(1)
    end

    it 'parses mixed case "Satisfied by:"' do
      pref = @p1_c1.prefix
      rule_id_one = @p1_c1.rules.first.rule_id
      sb = @p1_c1.rules.last
      sb.vendor_comments = "Satisfied by: #{pref}-#{rule_id_one}."
      sb.save!
      @p1_c1.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(1)
    end

    it 'parses "Satisfies:" as the reverse direction' do
      pref = @p1_c1.prefix
      parent = @p1_c1.rules.first
      child = @p1_c1.rules.last
      child.vendor_comments = "Satisfies: #{pref}-#{parent.rule_id}."
      child.save!
      @p1_c1.create_rule_satisfactions
      # child satisfies parent → child.satisfies includes parent
      expect(child.reload.satisfies.size).to eq(1)
      expect(child.satisfies.first.id).to eq(parent.id)
    end

    it 'parses lowercase "satisfies:"' do
      pref = @p1_c1.prefix
      parent = @p1_c1.rules.first
      child = @p1_c1.rules.last
      child.vendor_comments = "satisfies: #{pref}-#{parent.rule_id}"
      child.save!
      @p1_c1.create_rule_satisfactions
      expect(child.reload.satisfies.size).to eq(1)
    end

    it 'parses semicolon-separated lists' do
      pref = @p1_c1.prefix
      rule_id_one = @p1_c1.rules.first.rule_id
      rule_id_two = @p1_c1.rules.second.rule_id
      sb = @p1_c1.rules.last
      sb.vendor_comments = "Satisfied By: #{pref}-#{rule_id_one}; #{pref}-#{rule_id_two}."
      sb.save!
      @p1_c1.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(2)
    end

    it 'handles vendor_comments with other text before the satisfaction keyword' do
      pref = @p1_c1.prefix
      rule_id_one = @p1_c1.rules.first.rule_id
      sb = @p1_c1.rules.last
      sb.vendor_comments = "Some other comment. Satisfied By: #{pref}-#{rule_id_one}."
      sb.save!
      @p1_c1.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(1)
    end
  end
end
