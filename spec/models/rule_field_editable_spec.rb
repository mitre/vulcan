# frozen_string_literal: true

# Requirements:
# Rule#field_editable?(field_key) returns false when ANY of these conditions apply:
#   1. Rule is inherited (has satisfied_by associations)
#   2. Rule is whole-locked (locked == true)
#   3. The field's section is locked (locked_fields has the section name)
# Otherwise returns true.
#
# Rule#row_editable? returns false if the entire row is non-editable
# (inherited or whole-locked). Section locks don't make the whole row non-editable.

require 'rails_helper'

RSpec.describe Rule, '#field_editable?' do
  before do
    Rails.application.reload_routes!
  end

  let(:component) { create(:component) }
  let(:rule) { component.rules.first }

  describe 'direct, unlocked rule' do
    it 'returns true for any valid field' do
      expect(rule.field_editable?(:title)).to be true
      expect(rule.field_editable?(:status)).to be true
      expect(rule.field_editable?(:fixtext)).to be true
      expect(rule.field_editable?(:vuln_discussion)).to be true
      expect(rule.field_editable?(:rule_severity)).to be true
      expect(rule.field_editable?(:artifact_description)).to be true
      expect(rule.field_editable?(:vendor_comments)).to be true
    end

    it 'returns true for row_editable?' do
      expect(rule.row_editable?).to be true
    end
  end

  describe 'whole-locked rule' do
    before { rule.update!(locked: true) }

    it 'returns false for all fields' do
      expect(rule.field_editable?(:title)).to be false
      expect(rule.field_editable?(:status)).to be false
      expect(rule.field_editable?(:fixtext)).to be false
      expect(rule.field_editable?(:vuln_discussion)).to be false
    end

    it 'returns false for row_editable?' do
      expect(rule.row_editable?).to be false
    end
  end

  describe 'inherited rule (has satisfied_by)' do
    let(:other_rule) { component.rules.second || component.rules.last }

    before do
      # Create satisfied_by relationship: rule is inherited from other_rule
      rule.satisfied_by << other_rule unless rule.satisfied_by.include?(other_rule)
    end

    it 'returns false for all fields' do
      expect(rule.field_editable?(:title)).to be false
      expect(rule.field_editable?(:status)).to be false
      expect(rule.field_editable?(:fixtext)).to be false
    end

    it 'returns false for row_editable?' do
      expect(rule.row_editable?).to be false
    end
  end

  describe 'section-locked rule' do
    context 'with Title section locked' do
      before { rule.update!(locked_fields: { 'Title' => true }) }

      it 'returns false for fields in the locked section' do
        expect(rule.field_editable?(:title)).to be false
      end

      it 'returns true for fields in unlocked sections' do
        expect(rule.field_editable?(:status)).to be true
        expect(rule.field_editable?(:fixtext)).to be true
        expect(rule.field_editable?(:vuln_discussion)).to be true
        expect(rule.field_editable?(:rule_severity)).to be true
      end

      it 'returns true for row_editable? (partial lock does not lock whole row)' do
        expect(rule.row_editable?).to be true
      end
    end

    context 'with multiple sections locked' do
      before { rule.update!(locked_fields: { 'Title' => true, 'Status' => true, 'Fix' => true }) }

      it 'returns false for fields in any locked section' do
        expect(rule.field_editable?(:title)).to be false
        expect(rule.field_editable?(:status)).to be false
        expect(rule.field_editable?(:status_justification)).to be false
        expect(rule.field_editable?(:fixtext)).to be false
      end

      it 'returns true for fields in unlocked sections' do
        expect(rule.field_editable?(:vuln_discussion)).to be true
        expect(rule.field_editable?(:rule_severity)).to be true
        expect(rule.field_editable?(:artifact_description)).to be true
      end
    end

    context 'with Check section locked' do
      before { rule.update!(locked_fields: { 'Check' => true }) }

      it 'returns false for check-related fields' do
        expect(rule.field_editable?(:check_content)).to be false
      end

      it 'returns true for non-check fields' do
        expect(rule.field_editable?(:title)).to be true
        expect(rule.field_editable?(:fixtext)).to be true
      end
    end
  end

  describe 'combined locks' do
    context 'whole-locked AND section-locked' do
      before do
        rule.update!(locked_fields: { 'Title' => true })
        rule.update!(locked: true)
      end

      it 'returns false for all fields (whole lock takes precedence)' do
        expect(rule.field_editable?(:title)).to be false
        expect(rule.field_editable?(:status)).to be false
      end
    end
  end

  describe 'edge cases' do
    it 'raises ArgumentError for unknown field keys' do
      expect { rule.field_editable?(:nonexistent_field) }.to raise_error(ArgumentError, /unknown/i)
    end

    it 'handles string field keys by converting to symbol' do
      expect(rule.field_editable?('title')).to be true
    end

    it 'handles nil locked_fields gracefully' do
      rule.update_columns(locked_fields: nil)
      rule.reload
      expect(rule.field_editable?(:title)).to be true
    end

    it 'handles empty locked_fields hash' do
      rule.update!(locked_fields: {})
      expect(rule.field_editable?(:title)).to be true
    end
  end
end
