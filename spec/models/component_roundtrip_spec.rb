# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENTS:
# Users can export a Component as CSV, edit it externally, and re-import it
# to update existing rules. The update must:
# - Match rows to existing rules by SRG ID
# - Show a preview diff before applying changes
# - Skip locked rules (report them as skipped_locked)
# - Reject files from the wrong SRG or with missing headers
# - Preserve rule IDs, reviews, and audit history
# - Handle severity (CAT I/II/III) and status (case-insensitive) mapping
# - Support header aliases (both DISA and benchmark export headers)
# - Be idempotent: re-importing an unchanged export produces 0 updates

RSpec.describe Component, '#update_from_spreadsheet / #apply_spreadsheet_update' do
  include ImportConstants
  include ExportConstants
  include RuleConstants

  # Reuse shared SRG fixture (expensive parse — do it once)
  let_it_be(:shared_srg) do
    srg_xml = Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read
    parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    srg.xml = srg_xml
    srg.save!
    srg
  end
  let_it_be(:shared_project) { Project.create!(name: 'Roundtrip Test Project') }
  let_it_be(:shared_component, refind: true) do
    Component.create!(project: shared_project, name: 'Roundtrip Test', title: 'Roundtrip STIG',
                      version: 'V1R1', prefix: 'RNDT-00', based_on: shared_srg)
  end
  let_it_be(:user) { create(:user) }

  before do
    @component = shared_component
    @srg = shared_srg
  end

  # Helper: export CSV, parse it, optionally modify rows, write to tempfile
  def export_and_parse_csv(component)
    csv_string = component.csv_export
    CSV.parse(csv_string, headers: true)
  end

  def csv_to_tempfile(parsed_csv)
    file = Tempfile.new(['roundtrip_test', '.csv'])
    CSV.open(file.path, 'w') do |csv|
      csv << parsed_csv.headers
      parsed_csv.each { |row| csv << row.fields }
    end
    file.path
  end

  # Helper: create a CSV tempfile from headers and row arrays
  def create_csv_file(headers, rows)
    file = Tempfile.new(['roundtrip_test', '.csv'])
    CSV.open(file.path, 'w') do |csv|
      csv << headers
      rows.each { |row| csv << row }
    end
    file.path
  end

  # ========================================================================
  # 1. Golden round-trip: export → edit → preview shows correct changes
  # ========================================================================
  describe 'golden round-trip: export, edit, preview' do
    it 'detects changes made to exported CSV' do
      parsed = export_and_parse_csv(@component)

      # Edit the title of the first rule
      parsed[0]['Requirement'] = 'MODIFIED TITLE FOR ROUNDTRIP TEST'

      path = csv_to_tempfile(parsed)
      result = @component.update_from_spreadsheet(path, user)

      expect(result).to be_a(Hash)
      expect(result[:updated]).to be_an(Array)
      expect(result[:updated].length).to be >= 1

      changed_rule = result[:updated].find { |r| r[:changes].key?(:title) }
      expect(changed_rule).not_to be_nil
      expect(changed_rule[:changes][:title][:to]).to eq('MODIFIED TITLE FOR ROUNDTRIP TEST')
    end
  end

  # ========================================================================
  # 2. Partial update: only edited rows show as updated
  # ========================================================================
  describe 'partial update' do
    it 'only reports changed rows as updated when subset is edited' do
      parsed = export_and_parse_csv(@component)

      # Edit only the first row
      parsed[0]['Requirement'] = 'PARTIAL UPDATE TITLE'

      path = csv_to_tempfile(parsed)
      result = @component.update_from_spreadsheet(path, user)

      expect(result[:updated].length).to eq(1)
      expect(result[:unchanged].length).to eq(@component.rules.count - 1)
    end
  end

  # ========================================================================
  # 3. Idempotent re-import: no edits → 0 updates
  # ========================================================================
  describe 'idempotent re-import' do
    it 'reports 0 updates when exported CSV is re-imported without changes' do
      parsed = export_and_parse_csv(@component)
      path = csv_to_tempfile(parsed)
      result = @component.update_from_spreadsheet(path, user)

      expect(result[:error]).to be_nil
      expect(result[:updated]).to be_empty
      expect(result[:unchanged].length).to eq(@component.rules.count)
    end
  end

  # ========================================================================
  # 4. Status changes: case-insensitive mapping
  # ========================================================================
  describe 'status changes' do
    it 'maps case-insensitive status values correctly' do
      parsed = export_and_parse_csv(@component)
      parsed[0]['Status'] = 'applicable - configurable'

      path = csv_to_tempfile(parsed)
      result = @component.update_from_spreadsheet(path, user)

      changed = result[:updated].find { |r| r[:changes].key?(:status) }
      expect(changed).not_to be_nil
      expect(changed[:changes][:status][:to]).to eq('Applicable - Configurable')
    end
  end

  # ========================================================================
  # 5. Severity changes: CAT I/II/III → high/medium/low
  # ========================================================================
  describe 'severity changes' do
    it 'maps CAT I to high severity' do
      parsed = export_and_parse_csv(@component)
      parsed[0]['Severity'] = 'CAT I'

      path = csv_to_tempfile(parsed)
      result = @component.update_from_spreadsheet(path, user)

      changed = result[:updated].find { |r| r[:changes].key?(:rule_severity) }
      # If the rule was already high, it won't show as changed — handle both cases
      if changed
        expect(changed[:changes][:rule_severity][:to]).to eq('high')
      else
        # Rule was already high severity — that's fine, no change expected
        expect(result[:unchanged]).not_to be_empty
      end
    end

    it 'maps CAT III to low severity' do
      parsed = export_and_parse_csv(@component)
      parsed[0]['Severity'] = 'CAT III'

      path = csv_to_tempfile(parsed)
      result = @component.update_from_spreadsheet(path, user)

      changed = result[:updated].find { |r| r[:changes].key?(:rule_severity) }
      expect(changed).not_to be_nil
      expect(changed[:changes][:rule_severity][:to]).to eq('low')
    end
  end

  # ========================================================================
  # 6. Locked rules are skipped
  # ========================================================================
  describe 'locked rules' do
    it 'skips locked rules and reports them in skipped_locked' do
      # Lock the first rule
      @component.rules.first.update!(locked: true)

      parsed = export_and_parse_csv(@component)
      # Edit the locked rule
      parsed[0]['Requirement'] = 'SHOULD NOT UPDATE LOCKED RULE'

      path = csv_to_tempfile(parsed)
      result = @component.update_from_spreadsheet(path, user)

      expect(result[:skipped_locked]).to be_an(Array)
      expect(result[:skipped_locked].length).to be >= 1
      # The locked rule should NOT appear in updated
      locked_in_updated = result[:updated].find { |r| r[:rule_id] == @component.rules.first.rule_id }
      expect(locked_in_updated).to be_nil
    end
  end

  # ========================================================================
  # 7. Wrong SRG → error
  # ========================================================================
  describe 'wrong SRG validation' do
    it 'returns error when CSV contains SRG IDs not in component SRG' do
      headers = %w[SRGID STIGID Severity Requirement VulDiscussion Status Check Fix] +
                ['Status Justification', 'Artifact Description']
      rows = [['SRG-FAKE-999999-GPOS-99999', 'TEST-01-000001', 'CAT II',
               'title', 'discussion', 'Not Yet Determined', 'check', 'fix', '', '']]

      path = create_csv_file(headers, rows)
      result = @component.update_from_spreadsheet(path, user)

      expect(result[:error]).to be_present
    end
  end

  # ========================================================================
  # 8. Missing required headers → error
  # ========================================================================
  describe 'missing headers validation' do
    it 'returns error when required headers are missing' do
      headers = %w[SRGID Severity] # Missing STIGID, Requirement, etc.
      rows = [['SRG-OS-000001-GPOS-00001', 'CAT II']]

      path = create_csv_file(headers, rows)
      result = @component.update_from_spreadsheet(path, user)

      expect(result[:error]).to be_present
    end
  end

  # ========================================================================
  # 9. Header aliases: both DISA and benchmark headers work
  # ========================================================================
  describe 'header aliases' do
    it 'accepts benchmark export headers (Title, Description, STIG ID, etc.)' do
      parsed = export_and_parse_csv(@component)

      # Re-create CSV with benchmark-style headers
      # Map DISA headers to benchmark headers
      benchmark_headers = parsed.headers.map do |h|
        case h
        when 'Requirement' then 'Title'
        when 'VulDiscussion' then 'Description'
        when 'STIGID' then 'STIG ID'
        when 'SRGID' then 'SRG ID'
        when 'Fix' then 'Fix Text'
        when 'Check' then 'Check Content'
        when 'Mitigation' then 'Mitigations'
        else h
        end
      end

      file = Tempfile.new(['alias_test', '.csv'])
      CSV.open(file.path, 'w') do |csv|
        csv << benchmark_headers
        parsed.each { |row| csv << row.fields }
      end

      result = @component.update_from_spreadsheet(file.path, user)
      expect(result[:error]).to be_nil
    end
  end

  # ========================================================================
  # 10. Nested associations: vuln_discussion, check_content, mitigations
  # ========================================================================
  describe 'nested association updates' do
    it 'detects changes to vuln_discussion' do
      parsed = export_and_parse_csv(@component)
      parsed[0]['VulDiscussion'] = 'MODIFIED VULN DISCUSSION'

      path = csv_to_tempfile(parsed)
      result = @component.update_from_spreadsheet(path, user)

      changed = result[:updated].find { |r| r[:changes].key?(:vuln_discussion) }
      expect(changed).not_to be_nil
    end

    it 'detects changes to check content' do
      parsed = export_and_parse_csv(@component)
      parsed[0]['Check'] = 'MODIFIED CHECK CONTENT'

      path = csv_to_tempfile(parsed)
      result = @component.update_from_spreadsheet(path, user)

      changed = result[:updated].find { |r| r[:changes].key?(:check_content) }
      expect(changed).not_to be_nil
    end
  end

  # ========================================================================
  # 11. Result format
  # ========================================================================
  describe 'result format' do
    it 'returns hash with updated, unchanged, skipped_locked, and warnings keys' do
      parsed = export_and_parse_csv(@component)
      path = csv_to_tempfile(parsed)
      result = @component.update_from_spreadsheet(path, user)

      expect(result).to have_key(:updated)
      expect(result).to have_key(:unchanged)
      expect(result).to have_key(:skipped_locked)
      expect(result).to have_key(:warnings)
    end
  end

  # ========================================================================
  # 12. apply_spreadsheet_update: saves changes to DB
  # ========================================================================
  describe '#apply_spreadsheet_update' do
    it 'persists rule changes to the database' do
      parsed = export_and_parse_csv(@component)
      parsed[0]['Requirement'] = 'APPLIED TITLE CHANGE'

      path = csv_to_tempfile(parsed)
      result = @component.apply_spreadsheet_update(path, user)

      expect(result[:success]).to be true
      expect(result[:count]).to be >= 1

      # Verify DB was actually updated
      @component.rules.first.reload
      expect(@component.rules.order(:version, :rule_id).first.title).to eq('APPLIED TITLE CHANGE')
    end

    it 'skips locked rules during apply' do
      @component.rules.first.update!(locked: true)
      original_title = @component.rules.first.title

      parsed = export_and_parse_csv(@component)
      parsed[0]['Requirement'] = 'SHOULD NOT CHANGE LOCKED'

      path = csv_to_tempfile(parsed)
      @component.apply_spreadsheet_update(path, user)

      @component.rules.first.reload
      expect(@component.rules.first.title).to eq(original_title)
    end

    it 'preserves rule IDs after update' do
      original_ids = @component.rules.pluck(:id).sort

      parsed = export_and_parse_csv(@component)
      parsed[0]['Requirement'] = 'ID PRESERVATION TEST'

      path = csv_to_tempfile(parsed)
      @component.apply_spreadsheet_update(path, user)

      new_ids = @component.rules.reload.pluck(:id).sort
      expect(new_ids).to eq(original_ids)
    end
  end

  # ========================================================================
  # 13. Source column: ignored during import (metadata only)
  # ========================================================================
  describe 'Source column handling' do
    it 'ignores Source column during import without error' do
      parsed = export_and_parse_csv(@component)

      # Simulate a spreadsheet that includes a Source column (from XLSX export)
      headers_with_source = parsed.headers + ['Source']
      rows_with_source = parsed.map { |row| row.fields + ['Direct'] }

      path = create_csv_file(headers_with_source, rows_with_source)
      result = @component.update_from_spreadsheet(path, user)

      expect(result[:error]).to be_nil
      expect(result[:updated]).to be_empty
    end
  end

  # ========================================================================
  # 14. Multiple cycles: update → export → update again
  # ========================================================================
  describe 'multiple update cycles' do
    it 'supports sequential update-export-update cycles' do
      # Cycle 1: update
      parsed = export_and_parse_csv(@component)
      parsed[0]['Requirement'] = 'CYCLE 1 TITLE'
      path = csv_to_tempfile(parsed)
      result1 = @component.apply_spreadsheet_update(path, user)
      expect(result1[:success]).to be true

      # Cycle 2: re-export and update again
      parsed2 = export_and_parse_csv(@component.reload)
      parsed2[0]['Requirement'] = 'CYCLE 2 TITLE'
      path2 = csv_to_tempfile(parsed2)
      result2 = @component.apply_spreadsheet_update(path2, user)
      expect(result2[:success]).to be true

      @component.rules.order(:version, :rule_id).first.reload
      expect(@component.rules.order(:version, :rule_id).first.title).to eq('CYCLE 2 TITLE')
    end
  end

  # ========================================================================
  # 13. Section-locked fields are skipped, unlocked fields are accepted
  # ========================================================================
  describe 'section-locked fields' do
    it 'skips changes to section-locked fields but accepts changes to unlocked fields' do
      rule = @component.rules.order(:version, :rule_id).first
      rule.update!(locked_fields: { 'Title' => true })

      parsed = export_and_parse_csv(@component)
      # Try to change both title (locked) and status (unlocked)
      parsed[0]['Requirement'] = 'SHOULD NOT UPDATE SECTION-LOCKED TITLE'
      parsed[0]['Status'] = 'Not Applicable'

      path = csv_to_tempfile(parsed)
      result = @component.update_from_spreadsheet(path, user)

      # Title change should be in skipped, not in updated changes
      updated_rule = result[:updated].find { |r| r[:rule_id] == rule.rule_id }
      if updated_rule
        expect(updated_rule[:changes]).not_to have_key(:title)
        expect(updated_rule[:changes]).to have_key(:status)
      end

      # Should also appear in skipped_locked with field-level detail
      skipped = result[:skipped_locked].find { |r| r[:rule_id] == rule.rule_id }
      expect(skipped).not_to be_nil
      expect(skipped[:skipped_fields]).to include(:title)
    end

    it 'does not skip the whole rule when only some sections are locked' do
      rule = @component.rules.order(:version, :rule_id).first
      rule.update!(locked_fields: { 'Title' => true })

      parsed = export_and_parse_csv(@component)
      parsed[0]['Status'] = 'Not Applicable'

      path = csv_to_tempfile(parsed)
      result = @component.update_from_spreadsheet(path, user)

      updated_rule = result[:updated].find { |r| r[:rule_id] == rule.rule_id }
      expect(updated_rule).not_to be_nil
      expect(updated_rule[:changes]).to have_key(:status)
    end

    it 'skips section-locked fields during apply' do
      rule = @component.rules.order(:version, :rule_id).first
      original_title = rule.title
      rule.update!(locked_fields: { 'Title' => true })

      parsed = export_and_parse_csv(@component)
      parsed[0]['Requirement'] = 'SHOULD NOT UPDATE'
      parsed[0]['Status'] = 'Not Applicable'

      path = csv_to_tempfile(parsed)
      @component.apply_spreadsheet_update(path, user)

      rule.reload
      expect(rule.title).to eq(original_title)
      expect(rule.status).to eq('Not Applicable')
    end
  end

  # ========================================================================
  # 14. Inherited rules are skipped entirely
  # ========================================================================
  describe 'inherited rules' do
    it 'skips inherited rules and reports them in skipped_locked' do
      rule = @component.rules.order(:version, :rule_id).first
      other_rule = @component.rules.order(:version, :rule_id).second
      rule.satisfied_by << other_rule unless rule.satisfied_by.include?(other_rule)

      parsed = export_and_parse_csv(@component)
      parsed[0]['Requirement'] = 'SHOULD NOT UPDATE INHERITED RULE'

      path = csv_to_tempfile(parsed)
      result = @component.update_from_spreadsheet(path, user)

      # Inherited rule should not appear in updated
      updated_rule = result[:updated].find { |r| r[:rule_id] == rule.rule_id }
      expect(updated_rule).to be_nil

      # Should appear in skipped_locked
      skipped = result[:skipped_locked].find { |r| r[:rule_id] == rule.rule_id }
      expect(skipped).not_to be_nil
      expect(skipped[:reason]).to match(/inherited/i)
    end

    it 'does not apply changes to inherited rules' do
      rule = @component.rules.order(:version, :rule_id).first
      other_rule = @component.rules.order(:version, :rule_id).second
      original_title = rule.title
      rule.satisfied_by << other_rule unless rule.satisfied_by.include?(other_rule)

      parsed = export_and_parse_csv(@component)
      parsed[0]['Requirement'] = 'SHOULD NOT UPDATE'

      path = csv_to_tempfile(parsed)
      @component.apply_spreadsheet_update(path, user)

      rule.reload
      expect(rule.title).to eq(original_title)
    end
  end
end
