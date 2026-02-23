# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: Validation error messages must include the specific field name
# and limit so users can fix their data. No generic "failed to import" messages.
RSpec.describe 'Input length validation error messages' do
  describe 'BaseRule' do
    # Use StigRule as concrete subclass (BaseRule is abstract via STI)
    let(:rule) { StigRule.new(rule_id: 'TEST-001', status: 'Not Yet Determined', rule_severity: 'medium') }

    it 'reports field name and max for title' do
      rule.title = 'x' * 1001
      rule.valid?
      expect(rule.errors.full_messages).to include('Title is too long (maximum is 1000 characters)')
    end

    it 'reports field name and max for fixtext' do
      rule.fixtext = 'x' * 10_001
      rule.valid?
      expect(rule.errors.full_messages).to include('Fixtext is too long (maximum is 10000 characters)')
    end

    it 'reports field name and max for ident' do
      rule.ident = 'C' * 2049
      rule.valid?
      expect(rule.errors.full_messages).to include('Ident is too long (maximum is 2048 characters)')
    end

    it 'reports field name and max for inspec_control_body' do
      rule.inspec_control_body = 'x' * 50_001
      rule.valid?
      expect(rule.errors.full_messages).to include('Inspec control body is too long (maximum is 50000 characters)')
    end

    it 'allows values at exactly the limit' do
      rule.title = 'x' * 1000
      rule.fixtext = 'x' * 10_000
      rule.ident = 'CCI-000001'
      rule.valid?
      expect(rule.errors[:title]).to be_empty
      expect(rule.errors[:fixtext]).to be_empty
      expect(rule.errors[:ident]).to be_empty
    end
  end

  describe 'DisaRuleDescription' do
    it 'reports field name and max for vuln_discussion' do
      desc = DisaRuleDescription.new(vuln_discussion: 'x' * 10_001)
      desc.valid?
      expect(desc.errors.full_messages).to include('Vuln discussion is too long (maximum is 10000 characters)')
    end

    it 'allows values at exactly the limit' do
      desc = DisaRuleDescription.new(vuln_discussion: 'x' * 10_000)
      desc.valid?
      expect(desc.errors[:vuln_discussion]).to be_empty
    end
  end

  describe 'Check' do
    it 'reports field name and max for content' do
      check = Check.new(content: 'x' * 10_001)
      check.valid?
      expect(check.errors.full_messages).to include('Content is too long (maximum is 10000 characters)')
    end

    it 'reports field name and max for system' do
      check = Check.new(system: 'x' * 256)
      check.valid?
      expect(check.errors.full_messages).to include('System is too long (maximum is 255 characters)')
    end
  end

  describe 'Import error message format' do
    it 'Stig model includes rule detail in error messages' do
      source = Rails.root.join('app/models/stig.rb').read
      expect(source).to include('rules failed to import:')
      expect(source).not_to include('Some rules failed to import successfully')
    end

    it 'SRG model includes rule detail in error messages' do
      source = Rails.root.join('app/models/security_requirements_guide.rb').read
      expect(source).to include('rules failed to import:')
      expect(source).not_to include('Some rules failed to import successfully')
    end
  end
end
