# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component do
  # Create SRG, project, and component ONCE. Each example gets a savepoint
  # that rollbacks any mutations (update_columns, rule locks, etc.).
  # This eliminates ~50 SRG parses + ~50 component rule imports.
  let_it_be(:shared_srg) do
    srg_xml = Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read
    parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    srg.xml = srg_xml
    srg.save!
    srg
  end
  let_it_be(:shared_project) { Project.create!(name: 'Photon OS 3') }
  let_it_be(:shared_component, refind: true) do
    Component.create!(project: shared_project, name: 'Photon OS 3', title: 'Photon OS 3 STIG',
                      version: 'Photon OS 3 V1R1', prefix: 'PHOS-03', based_on: shared_srg)
  end

  before do
    @srg = shared_srg
    @p1 = shared_project
    @p1_c1 = shared_component
  end

  context 'component release' do
    it 'onlies allow release when all rules are locked' do
      expect(@p1_c1.valid?).to be(true)
      @p1_c1.released = true
      expect(@p1_c1.valid?).to be(false)
      expect(@p1_c1.errors[:base]).to include('Cannot release a component that contains rules that are not yet locked')
    end

    it 'onlies allow depending on a released component' do
      p1_c2 = Component.new(project: @p1, name: 'Photon OS 3 V2', title: 'Photon OS 3 STIG V2', version: 'Photon OS 3 V1R2', prefix: 'PHOS-03', based_on: @srg,
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
      expect(sb.reload.satisfied_by.size).to eq(2)
    end

    it 'correctly establishes rule satisfactions relation when a rule is satisfied by another rule' do
      pref = @p1_c1.prefix
      rule_id_one = @p1_c1.rules.first.rule_id
      sb = @p1_c1.rules.last
      sb.vendor_comments = "Satisfied By: #{pref}-#{rule_id_one}"
      sb.save!
      @p1_c1.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(1)
    end

    it 'parses satisfied by list with trailing period' do
      pref = @p1_c1.prefix
      rule_id_one = @p1_c1.rules.first.rule_id
      rule_id_two = @p1_c1.rules.second.rule_id
      sb = @p1_c1.rules.last
      sb.vendor_comments = "Satisfied By: #{pref}-#{rule_id_one}, #{pref}-#{rule_id_two}."
      sb.save!
      @p1_c1.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(2)
    end

    it 'parses satisfied by list without trailing period' do
      pref = @p1_c1.prefix
      rule_id_one = @p1_c1.rules.first.rule_id
      rule_id_two = @p1_c1.rules.second.rule_id
      sb = @p1_c1.rules.last
      sb.vendor_comments = "Satisfied By: #{pref}-#{rule_id_one}, #{pref}-#{rule_id_two}"
      sb.save!
      @p1_c1.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(2)
    end

    it 'parses satisfied by list with extra whitespace' do
      pref = @p1_c1.prefix
      rule_id_one = @p1_c1.rules.first.rule_id
      sb = @p1_c1.rules.last
      sb.vendor_comments = "Satisfied By: #{pref}-#{rule_id_one}   ."
      sb.save!
      @p1_c1.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(1)
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

    # XCCDF import gap: satisfaction text in VulnDiscussion (not vendor_comments)
    # REQUIREMENT: When XCCDF is imported, satisfaction text lives in
    # disa_rule_descriptions.vuln_discussion — must be parsed just like vendor_comments.

    it 'parses satisfaction from vuln_discussion when vendor_comments is empty' do
      parent = @p1_c1.rules.first
      child = @p1_c1.rules.last
      srg_id = parent.srg_rule.version # e.g., "SRG-OS-000480-GPOS-00227"

      # Simulate XCCDF import: satisfaction text in vuln_discussion, not vendor_comments
      child.disa_rule_descriptions.first.update!(
        vuln_discussion: "This control addresses xyz. Satisfies: #{srg_id}"
      )
      child.update_column(:vendor_comments, nil)

      @p1_c1.create_rule_satisfactions
      expect(child.reload.satisfies.size).to eq(1)
      expect(child.satisfies.first.id).to eq(parent.id)
    end

    it 'resolves SRG IDs (SRG-OS-000480-GPOS-00227) by srg_rule.version' do
      parent = @p1_c1.rules.first
      child = @p1_c1.rules.second
      srg_id = parent.srg_rule.version

      child.vendor_comments = "Satisfies: #{srg_id}."
      child.save!

      @p1_c1.create_rule_satisfactions
      expect(child.reload.satisfies.size).to eq(1)
      expect(child.satisfies.first.id).to eq(parent.id)
    end

    it 'resolves multiple SRG IDs from vuln_discussion' do
      parent1 = @p1_c1.rules.first
      parent2 = @p1_c1.rules.second
      child = @p1_c1.rules.last
      srg_id1 = parent1.srg_rule.version
      srg_id2 = parent2.srg_rule.version

      child.disa_rule_descriptions.first.update!(
        vuln_discussion: "Requirement text. Satisfies: #{srg_id1}, #{srg_id2}."
      )
      child.update_column(:vendor_comments, nil)

      @p1_c1.create_rule_satisfactions
      expect(child.reload.satisfies.size).to eq(2)
    end

    it 'strips satisfaction text from vuln_discussion after parsing' do
      parent = @p1_c1.rules.first
      child = @p1_c1.rules.last
      srg_id = parent.srg_rule.version
      base_text = 'This control addresses the requirement for secure configuration.'

      child.disa_rule_descriptions.first.update!(
        vuln_discussion: "#{base_text} Satisfies: #{srg_id}."
      )
      child.update_column(:vendor_comments, nil)

      @p1_c1.create_rule_satisfactions
      child.reload
      # Only the satisfaction keyword and data is stripped; user's text (including period) preserved
      expect(child.disa_rule_descriptions.first.vuln_discussion).to eq(base_text)
    end

    it 'does not create duplicate relationships when both sources have satisfaction text' do
      pref = @p1_c1.prefix
      parent = @p1_c1.rules.first
      child = @p1_c1.rules.last
      srg_id = parent.srg_rule.version

      # Same relationship expressed in both sources
      child.vendor_comments = "Satisfies: #{pref}-#{parent.rule_id}."
      child.save!
      child.disa_rule_descriptions.first.update!(
        vuln_discussion: "Some text. Satisfies: #{srg_id}."
      )

      @p1_c1.create_rule_satisfactions
      expect(child.reload.satisfies.size).to eq(1)
    end

    it 'parses "Satisfied By:" with SRG IDs from vuln_discussion' do
      parent = @p1_c1.rules.last
      child = @p1_c1.rules.first
      srg_id = child.srg_rule.version

      parent.disa_rule_descriptions.first.update!(
        vuln_discussion: "Requirement text. Satisfied By: #{srg_id}."
      )
      parent.update_column(:vendor_comments, nil)

      @p1_c1.create_rule_satisfactions
      expect(parent.reload.satisfied_by.size).to eq(1)
      expect(parent.satisfied_by.first.id).to eq(child.id)
    end
  end

  context 'CSV export/import roundtrip for satisfaction relationships' do
    # REQUIREMENT: Export a component with satisfaction relationships to CSV,
    # re-import it, and the satisfaction relationships survive the roundtrip.

    it 'exports satisfaction relationships in a dedicated Satisfies column' do
      parent = @p1_c1.rules.first
      child = @p1_c1.rules.second
      child.satisfies << parent
      child.save!

      csv_data = @p1_c1.csv_export
      parsed = CSV.parse(csv_data, headers: true)

      # Verify 'Satisfies' header exists
      expect(parsed.headers).to include('Satisfies')

      child_row = parsed.find { |row| row['STIGID'] == "#{@p1_c1.prefix}-#{child.rule_id}" }
      expect(child_row).not_to be_nil
      expect(child_row['Satisfies']).to be_present
      expect(child_row['Satisfies']).to include(parent.rule_id)

      # Vendor Comments column should be clean (no satisfaction text)
      expect(child_row['Vendor Comments']).to be_nil.or(
        satisfy { |v| !v.match?(/satisfi/i) }
      )
    end

    it 'keeps vendor comments separate from satisfaction in export' do
      parent = @p1_c1.rules.first
      child = @p1_c1.rules.second
      child.satisfies << parent
      child.update!(vendor_comments: 'Important security note.')

      csv_data = @p1_c1.csv_export
      parsed = CSV.parse(csv_data, headers: true)
      child_row = parsed.find { |row| row['STIGID'] == "#{@p1_c1.prefix}-#{child.rule_id}" }

      expect(child_row['Vendor Comments']).to eq('Important security note.')
      expect(child_row['Satisfies']).to be_present
      expect(child_row['Satisfies']).not_to include('Important security note')
    end

    it 'imports satisfaction from Satisfies column via create_rule_satisfactions' do
      # Simulate what happens after spreadsheet import: vendor_comments has
      # satisfaction text appended from the Satisfies column
      pref = @p1_c1.prefix
      parent = @p1_c1.rules.first
      child = @p1_c1.rules.second

      # This is what the import loop does: appends "Satisfies: PREFIX-ID" to vendor_comments
      child.update_column(:vendor_comments, "Satisfies: #{pref}-#{parent.rule_id}")

      @p1_c1.create_rule_satisfactions

      child.reload
      expect(child.satisfies.size).to eq(1)
      expect(child.satisfies.first.id).to eq(parent.id)
      # vendor_comments should be clean after parsing
      expect(child.vendor_comments).to be_nil
    end

    it 'preserves user vendor comments alongside imported satisfaction' do
      pref = @p1_c1.prefix
      parent = @p1_c1.rules.first
      child = @p1_c1.rules.second

      # Simulate import with both vendor comments and satisfaction
      child.update_column(:vendor_comments,
                          "Important note. Satisfies: #{pref}-#{parent.rule_id}")

      @p1_c1.create_rule_satisfactions

      child.reload
      expect(child.satisfies.size).to eq(1)
      expect(child.vendor_comments).to eq('Important note.')
    end
  end

  context 'severity_counts' do
    it 'returns aggregated severity counts' do
      # Component has rules from SRG setup (reload to load imported rules)
      @p1_c1.reload
      counts = @p1_c1.severity_counts
      expect(counts).to be_a(Hash)
      expect(counts.keys).to contain_exactly(:high, :medium, :low)
      expect(counts[:high]).to be >= 0
      expect(counts[:medium]).to be >= 0
      expect(counts[:low]).to be >= 0
      expect(counts[:high] + counts[:medium] + counts[:low]).to eq(@p1_c1.rules_count)
    end

    it 'includes severity_counts in as_json when requested' do
      json = @p1_c1.as_json(methods: [:severity_counts])
      expect(json['severity_counts']).to be_a(Hash)
      expect(json['severity_counts']['high']).to be >= 0
    end

    it 'counts high severity rules correctly' do
      # Add a high severity rule
      @p1_c1.rules.first.update(rule_severity: 'high')
      counts = @p1_c1.severity_counts
      expect(counts[:high]).to be >= 1
    end

    it 'counts medium severity rules correctly' do
      # Add a medium severity rule
      @p1_c1.rules.first.update(rule_severity: 'medium')
      counts = @p1_c1.severity_counts
      expect(counts[:medium]).to be >= 1
    end

    it 'counts low severity rules correctly' do
      # Add a low severity rule
      @p1_c1.rules.first.update(rule_severity: 'low')
      counts = @p1_c1.severity_counts
      expect(counts[:low]).to be >= 1
    end

    it 'returns zero counts for components with no rules' do
      empty_component = Component.create!(project: @p1, name: 'Empty Component', title: 'Empty STIG',
                                          version: 'Empty V1R1', prefix: 'EMPT-00', based_on: @srg,
                                          skip_import_srg_rules: true)
      counts = empty_component.severity_counts
      expect(counts[:high]).to eq(0)
      expect(counts[:medium]).to eq(0)
      expect(counts[:low]).to eq(0)
    end
  end

  context 'with_severity_counts scope' do
    it 'adds severity count virtual columns' do
      @p1_c1.reload

      component = Component.with_severity_counts.find(@p1_c1.id)
      expect(component).to respond_to(:severity_high_count)
      expect(component).to respond_to(:severity_medium_count)
      expect(component).to respond_to(:severity_low_count)
    end

    it 'returns correct severity counts as virtual columns', :aggregate_failures do
      @p1_c1.reload

      component = Component.with_severity_counts.find(@p1_c1.id)

      # Verify counts are integers
      expect(component.severity_high_count).to be_a(Integer)
      expect(component.severity_medium_count).to be_a(Integer)
      expect(component.severity_low_count).to be_a(Integer)

      # Verify counts sum to total rules
      total = component.severity_high_count + component.severity_medium_count + component.severity_low_count
      expect(total).to eq(@p1_c1.rules_count)

      # Verify counts are non-negative
      expect(component.severity_high_count).to be >= 0
      expect(component.severity_medium_count).to be >= 0
      expect(component.severity_low_count).to be >= 0
    end

    it 'handles components with no rules' do
      empty = Component.create!(project: @p1, name: 'Empty Component', title: 'Empty STIG',
                                version: 'Empty V1R1', prefix: 'EMPT-01', based_on: @srg,
                                skip_import_srg_rules: true)

      component = Component.with_severity_counts.find(empty.id)
      expect(component.severity_high_count).to eq(0)
      expect(component.severity_medium_count).to eq(0)
      expect(component.severity_low_count).to eq(0)
    end

    it 'counts match direct rule queries (no off-by-one)', :aggregate_failures do
      @p1_c1.reload

      # Get counts from scope
      component = Component.with_severity_counts.find(@p1_c1.id)

      # Get counts from direct queries
      expected_high = @p1_c1.rules.where(rule_severity: 'high').count
      expected_medium = @p1_c1.rules.where(rule_severity: 'medium').count
      expected_low = @p1_c1.rules.where(rule_severity: 'low').count

      # Scope counts should exactly match direct queries
      expect(component.severity_high_count).to eq(expected_high)
      expect(component.severity_medium_count).to eq(expected_medium)
      expect(component.severity_low_count).to eq(expected_low)
    end
  end

  describe '#status_counts' do
    it 'returns counts for each rule status' do
      counts = @p1_c1.status_counts
      expect(counts).to have_key(:not_yet_determined)
      expect(counts).to have_key(:applicable_configurable)
      expect(counts).to have_key(:applicable_inherently_meets)
      expect(counts).to have_key(:applicable_does_not_meet)
      expect(counts).to have_key(:not_applicable)

      # All rules default to NYD
      total = @p1_c1.rules.where(deleted_at: nil).count
      expect(counts[:not_yet_determined]).to eq(total)
    end

    it 'reflects status changes' do
      rule = @p1_c1.rules.first
      rule.update!(status: 'Applicable - Configurable')

      counts = @p1_c1.status_counts
      expect(counts[:applicable_configurable]).to eq(1)
      expect(counts[:not_yet_determined]).to eq(@p1_c1.rules.where(deleted_at: nil).count - 1)
    end
  end

  describe '#as_json' do
    it 'includes status_counts' do
      json = @p1_c1.as_json
      # as_json merge uses symbol keys for custom additions
      expect(json).to have_key(:status_counts)
      expect(json[:status_counts]).to have_key(:not_yet_determined)
    end

    # REQUIREMENT: as_json must not crash when based_on (SRG) is nil.
    # This can happen with legacy data or components created without an SRG link.
    it 'handles nil based_on gracefully' do
      orphan = Component.new(
        project: @p1_c1.project, name: 'Orphan', title: 'Orphan STIG',
        version: 99, release: 1, prefix: 'ORPH-01'
      )
      # Skip validations to create a component without based_on
      orphan.save!(validate: false)

      expect { orphan.as_json }.not_to raise_error
      json = orphan.as_json
      expect(json[:based_on_title]).to be_nil
      expect(json[:based_on_version]).to be_nil

      orphan.destroy!
    end
  end

  # ─── B8 Regression: Duplicated component rules_count ─────
  # REQUIREMENT: When a component is duplicated, the new component's
  # rules_count must equal the actual number of rules, NOT accumulate
  # from the original's counter_cache value + new rule inserts.
  describe '#duplicate rules_count (B8 regression)' do
    it 'duplicated component has correct rules_count after save' do
      original = shared_component
      original_count = original.rules.where(deleted_at: nil).count
      expect(original_count).to be > 0

      dup = original.duplicate(new_version: 99, new_release: 99)
      dup.save!
      dup.reload

      # Without counter reset, rules_count may be double the actual count
      actual_count = dup.rules.where(deleted_at: nil).count
      expect(dup.rules_count).to eq(actual_count),
                                 "rules_count (#{dup.rules_count}) should equal actual count (#{actual_count}), " \
                                 "not #{original_count * 2} (counter_cache accumulation bug)"

      dup.destroy!
    end

    it 'duplicate_reviews_and_history copies without error' do
      original = shared_component
      dup = original.duplicate(new_version: 98, new_release: 98)
      dup.save!

      # This was raising TypeError (Rails 8 bind params) and
      # NoMethodError (sanitize_sql_array as instance method)
      expect { dup.duplicate_reviews_and_history(original.id) }.not_to raise_error

      dup.destroy!
    end
  end
end
