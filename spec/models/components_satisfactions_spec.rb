# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component do
  include_context 'components model base setup'

  context 'create rule satisfaction' do
    it 'correctly establishes rule satisfactions relation when a rule is satisfied by more than one other rules' do
      pref = components_component.prefix
      rule_id_one = components_component.rules.first.rule_id
      rule_id_two = components_component.rules.second.rule_id
      sb = components_component.rules.last
      sb.vendor_comments = "Satisfied By: #{pref}-#{rule_id_one}, #{pref}-#{rule_id_two}"
      sb.save!
      components_component.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(2)
    end

    it 'correctly establishes rule satisfactions relation when a rule is satisfied by another rule' do
      pref = components_component.prefix
      rule_id_one = components_component.rules.first.rule_id
      sb = components_component.rules.last
      sb.vendor_comments = "Satisfied By: #{pref}-#{rule_id_one}"
      sb.save!
      components_component.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(1)
    end

    it 'parses satisfied by list with trailing period' do
      pref = components_component.prefix
      rule_id_one = components_component.rules.first.rule_id
      rule_id_two = components_component.rules.second.rule_id
      sb = components_component.rules.last
      sb.vendor_comments = "Satisfied By: #{pref}-#{rule_id_one}, #{pref}-#{rule_id_two}."
      sb.save!
      components_component.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(2)
    end

    it 'parses satisfied by list without trailing period' do
      pref = components_component.prefix
      rule_id_one = components_component.rules.first.rule_id
      rule_id_two = components_component.rules.second.rule_id
      sb = components_component.rules.last
      sb.vendor_comments = "Satisfied By: #{pref}-#{rule_id_one}, #{pref}-#{rule_id_two}"
      sb.save!
      components_component.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(2)
    end

    it 'parses satisfied by list with extra whitespace' do
      pref = components_component.prefix
      rule_id_one = components_component.rules.first.rule_id
      sb = components_component.rules.last
      sb.vendor_comments = "Satisfied By: #{pref}-#{rule_id_one}   ."
      sb.save!
      components_component.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(1)
    end

    # Postel's Law: Be liberal in what you accept
    # All reasonable variations of "Satisfied By" and "Satisfies" should work

    it 'parses lowercase "satisfied by:"' do
      pref = components_component.prefix
      rule_id_one = components_component.rules.first.rule_id
      sb = components_component.rules.last
      sb.vendor_comments = "satisfied by: #{pref}-#{rule_id_one}."
      sb.save!
      components_component.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(1)
    end

    it 'parses uppercase "SATISFIED BY:"' do
      pref = components_component.prefix
      rule_id_one = components_component.rules.first.rule_id
      sb = components_component.rules.last
      sb.vendor_comments = "SATISFIED BY: #{pref}-#{rule_id_one}."
      sb.save!
      components_component.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(1)
    end

    it 'parses mixed case "Satisfied by:"' do
      pref = components_component.prefix
      rule_id_one = components_component.rules.first.rule_id
      sb = components_component.rules.last
      sb.vendor_comments = "Satisfied by: #{pref}-#{rule_id_one}."
      sb.save!
      components_component.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(1)
    end

    it 'parses "Satisfies:" as the reverse direction' do
      pref = components_component.prefix
      parent = components_component.rules.first
      child = components_component.rules.last
      child.vendor_comments = "Satisfies: #{pref}-#{parent.rule_id}."
      child.save!
      components_component.create_rule_satisfactions
      # child satisfies parent → child.satisfies includes parent
      expect(child.reload.satisfies.size).to eq(1)
      expect(child.satisfies.first.id).to eq(parent.id)
    end

    it 'parses lowercase "satisfies:"' do
      pref = components_component.prefix
      parent = components_component.rules.first
      child = components_component.rules.last
      child.vendor_comments = "satisfies: #{pref}-#{parent.rule_id}"
      child.save!
      components_component.create_rule_satisfactions
      expect(child.reload.satisfies.size).to eq(1)
    end

    it 'parses semicolon-separated lists' do
      pref = components_component.prefix
      rule_id_one = components_component.rules.first.rule_id
      rule_id_two = components_component.rules.second.rule_id
      sb = components_component.rules.last
      sb.vendor_comments = "Satisfied By: #{pref}-#{rule_id_one}; #{pref}-#{rule_id_two}."
      sb.save!
      components_component.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(2)
    end

    it 'handles vendor_comments with other text before the satisfaction keyword' do
      pref = components_component.prefix
      rule_id_one = components_component.rules.first.rule_id
      sb = components_component.rules.last
      sb.vendor_comments = "Some other comment. Satisfied By: #{pref}-#{rule_id_one}."
      sb.save!
      components_component.create_rule_satisfactions
      expect(sb.reload.satisfied_by.size).to eq(1)
    end

    # XCCDF import gap: satisfaction text in VulnDiscussion (not vendor_comments)
    # REQUIREMENT: When XCCDF is imported, satisfaction text lives in
    # disa_rule_descriptions.vuln_discussion — must be parsed just like vendor_comments.

    it 'parses satisfaction from vuln_discussion when vendor_comments is empty' do
      parent = components_component.rules.first
      child = components_component.rules.last
      srg_id = parent.srg_rule.version # e.g., "SRG-OS-000480-GPOS-00227"

      # Simulate XCCDF import: satisfaction text in vuln_discussion, not vendor_comments
      child.disa_rule_descriptions.first.update!(
        vuln_discussion: "This control addresses xyz. Satisfies: #{srg_id}"
      )
      child.update_column(:vendor_comments, nil)

      components_component.create_rule_satisfactions
      expect(child.reload.satisfies.size).to eq(1)
      expect(child.satisfies.first.id).to eq(parent.id)
    end

    it 'resolves SRG IDs (SRG-OS-000480-GPOS-00227) by srg_rule.version' do
      parent = components_component.rules.first
      child = components_component.rules.second
      srg_id = parent.srg_rule.version

      child.vendor_comments = "Satisfies: #{srg_id}."
      child.save!

      components_component.create_rule_satisfactions
      expect(child.reload.satisfies.size).to eq(1)
      expect(child.satisfies.first.id).to eq(parent.id)
    end

    it 'resolves multiple SRG IDs from vuln_discussion' do
      parent1 = components_component.rules.first
      parent2 = components_component.rules.second
      child = components_component.rules.last
      srg_id1 = parent1.srg_rule.version
      srg_id2 = parent2.srg_rule.version

      child.disa_rule_descriptions.first.update!(
        vuln_discussion: "Requirement text. Satisfies: #{srg_id1}, #{srg_id2}."
      )
      child.update_column(:vendor_comments, nil)

      components_component.create_rule_satisfactions
      expect(child.reload.satisfies.size).to eq(2)
    end

    it 'strips satisfaction text from vuln_discussion after parsing' do
      parent = components_component.rules.first
      child = components_component.rules.last
      srg_id = parent.srg_rule.version
      base_text = 'This control addresses the requirement for secure configuration.'

      child.disa_rule_descriptions.first.update!(
        vuln_discussion: "#{base_text} Satisfies: #{srg_id}."
      )
      child.update_column(:vendor_comments, nil)

      components_component.create_rule_satisfactions
      child.reload
      # Only the satisfaction keyword and data is stripped; user's text (including period) preserved
      expect(child.disa_rule_descriptions.first.vuln_discussion).to eq(base_text)
    end

    it 'does not create duplicate relationships when both sources have satisfaction text' do
      pref = components_component.prefix
      parent = components_component.rules.first
      child = components_component.rules.last
      srg_id = parent.srg_rule.version

      # Same relationship expressed in both sources
      child.vendor_comments = "Satisfies: #{pref}-#{parent.rule_id}."
      child.save!
      child.disa_rule_descriptions.first.update!(
        vuln_discussion: "Some text. Satisfies: #{srg_id}."
      )

      components_component.create_rule_satisfactions
      expect(child.reload.satisfies.size).to eq(1)
    end

    it 'parses "Satisfied By:" with SRG IDs from vuln_discussion' do
      parent = components_component.rules.last
      child = components_component.rules.first
      srg_id = child.srg_rule.version

      parent.disa_rule_descriptions.first.update!(
        vuln_discussion: "Requirement text. Satisfied By: #{srg_id}."
      )
      parent.update_column(:vendor_comments, nil)

      components_component.create_rule_satisfactions
      expect(parent.reload.satisfied_by.size).to eq(1)
      expect(parent.satisfied_by.first.id).to eq(child.id)
    end

    it 'skips self-reference — a rule does not satisfy itself' do
      self_ref_rule = components_component.rules.third
      self_ref_rule.update_column(:vendor_comments, "Satisfies: #{components_component.prefix}-#{self_ref_rule.rule_id}")

      components_component.create_rule_satisfactions

      expect(self_ref_rule.reload.satisfies.pluck(:id)).not_to include(self_ref_rule.id)
      expect(self_ref_rule.satisfied_by.pluck(:id)).not_to include(self_ref_rule.id)
    end
  end
end
