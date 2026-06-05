# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component do
  include_context 'components model base setup'

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
end
