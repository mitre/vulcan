# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: Validation error messages must include the specific field name
# and limit so users can fix their data. No generic "failed to import" messages.
# All limits reference Settings.input_limits for configurability.
RSpec.describe 'Input length validation error messages' do
  describe 'BaseRule' do
    # Use StigRule as concrete subclass (BaseRule is abstract via STI)
    let(:rule) { StigRule.new(rule_id: 'TEST-001', status: 'Not Yet Determined', rule_severity: 'medium') }
    let(:title_limit) { Settings.input_limits.title }
    let(:long_text_limit) { Settings.input_limits.long_text }
    let(:ident_limit) { Settings.input_limits.ident }
    let(:inspec_limit) { Settings.input_limits.inspec_code }

    it 'reports field name and max for title' do
      rule.title = 'x' * (title_limit + 1)
      rule.valid?
      expect(rule.errors.full_messages).to include("Title is too long (maximum is #{title_limit} characters)")
    end

    it 'reports field name and max for fixtext' do
      rule.fixtext = 'x' * (long_text_limit + 1)
      rule.valid?
      expect(rule.errors.full_messages).to include("Fixtext is too long (maximum is #{long_text_limit} characters)")
    end

    it 'reports field name and max for ident' do
      rule.ident = 'C' * (ident_limit + 1)
      rule.valid?
      expect(rule.errors.full_messages).to include("Ident is too long (maximum is #{ident_limit} characters)")
    end

    it 'reports field name and max for inspec_control_body' do
      rule.inspec_control_body = 'x' * (inspec_limit + 1)
      rule.valid?
      expect(rule.errors.full_messages).to include("Inspec control body is too long (maximum is #{inspec_limit} characters)")
    end

    it 'allows values at exactly the limit' do
      rule.title = 'x' * title_limit
      rule.fixtext = 'x' * long_text_limit
      rule.ident = 'CCI-000001'
      rule.valid?
      expect(rule.errors[:title]).to be_empty
      expect(rule.errors[:fixtext]).to be_empty
      expect(rule.errors[:ident]).to be_empty
    end
  end

  describe 'DisaRuleDescription' do
    let(:long_text_limit) { Settings.input_limits.long_text }

    it 'reports field name and max for vuln_discussion' do
      desc = DisaRuleDescription.new(vuln_discussion: 'x' * (long_text_limit + 1))
      desc.valid?
      expect(desc.errors.full_messages).to include("Vuln discussion is too long (maximum is #{long_text_limit} characters)")
    end

    it 'allows values at exactly the limit' do
      desc = DisaRuleDescription.new(vuln_discussion: 'x' * long_text_limit)
      desc.valid?
      expect(desc.errors[:vuln_discussion]).to be_empty
    end
  end

  describe 'Check' do
    let(:long_text_limit) { Settings.input_limits.long_text }
    let(:short_string_limit) { Settings.input_limits.short_string }

    it 'reports field name and max for content' do
      check = Check.new(content: 'x' * (long_text_limit + 1))
      check.valid?
      expect(check.errors.full_messages).to include("Content is too long (maximum is #{long_text_limit} characters)")
    end

    it 'reports field name and max for system' do
      check = Check.new(system: 'x' * (short_string_limit + 1))
      check.valid?
      expect(check.errors.full_messages).to include("System is too long (maximum is #{short_string_limit} characters)")
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
