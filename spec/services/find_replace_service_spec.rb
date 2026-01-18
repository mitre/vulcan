# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FindReplaceService, type: :service do
  let(:project) { create(:project) }
  let(:srg) { create(:security_requirements_guide) }
  let(:component) { create(:component, project: project, based_on: srg) }

  # Create rules with various content for testing
  let!(:rule1) do
    create(:rule, component: component, rule_id: 'SV-001',
                  title: 'Configure sshd service',
                  fixtext: 'Edit /etc/ssh/sshd_config and set PermitRootLogin no. Restart sshd service.',
                  vendor_comments: 'The sshd daemon must be properly configured.')
  end

  let!(:rule2) do
    create(:rule, component: component, rule_id: 'SV-002',
                  title: 'Configure SSH key authentication',
                  fixtext: 'Configure sshd to use key-based authentication only.',
                  vendor_comments: nil)
  end

  let!(:rule3) do
    create(:rule, component: component, rule_id: 'SV-003',
                  title: 'Disable password authentication',
                  fixtext: 'Set PasswordAuthentication to no in the configuration file.',
                  vendor_comments: 'This applies to all SSH connections.')
  end

  describe '#find' do
    context 'with valid search text' do
      it 'finds matches across multiple rules and fields' do
        service = described_class.new(component, 'sshd')
        result = service.find

        expect(result[:total_rules]).to eq(2)
        expect(result[:total_matches]).to be >= 4 # At least 4 occurrences of 'sshd'
        expect(result[:matches].pluck(:rule_identifier)).to contain_exactly('SV-001', 'SV-002')
      end

      it 'returns match instances with positions and context' do
        service = described_class.new(component, 'sshd')
        result = service.find

        rule1_match = result[:matches].find { |m| m[:rule_id] == rule1.id }
        expect(rule1_match).to be_present
        expect(rule1_match[:instances]).to be_an(Array)

        # Check that instances have required fields
        first_field = rule1_match[:instances].first
        expect(first_field[:field]).to be_present
        expect(first_field[:instances].first).to include(:index, :length, :text, :context)
      end

      it 'provides context around matches' do
        service = described_class.new(component, 'sshd_config')
        result = service.find

        rule1_match = result[:matches].find { |m| m[:rule_id] == rule1.id }
        fixtext_field = rule1_match[:instances].find { |i| i[:field] == 'fixtext' }
        instance = fixtext_field[:instances].first

        expect(instance[:context]).to include('sshd_config')
        expect(instance[:context].length).to be > instance[:text].length
      end
    end

    context 'with case sensitivity' do
      it 'is case-insensitive by default' do
        service = described_class.new(component, 'SSHD')
        result = service.find

        expect(result[:total_matches]).to be >= 4
      end

      it 'respects case_sensitive option when true' do
        service = described_class.new(component, 'SSHD', case_sensitive: true)
        result = service.find

        # No matches because content has lowercase 'sshd'
        expect(result[:total_matches]).to eq(0)
      end
    end

    context 'with field filtering' do
      it 'searches only specified fields' do
        service = described_class.new(component, 'sshd', fields: ['title'])
        result = service.find

        expect(result[:total_rules]).to eq(1) # Only rule1 has 'sshd' in title
        rule1_match = result[:matches].find { |m| m[:rule_id] == rule1.id }
        expect(rule1_match[:instances].pluck(:field)).to contain_exactly('title')
      end

      it 'ignores invalid field names' do
        service = described_class.new(component, 'sshd', fields: %w[invalid_field title])
        result = service.find

        expect(result[:total_rules]).to eq(1)
      end
    end

    context 'with edge cases' do
      it 'returns empty result for blank search text' do
        service = described_class.new(component, '')
        result = service.find

        expect(result[:total_matches]).to eq(0)
        expect(result[:matches]).to be_empty
      end

      it 'returns empty result for search text less than 2 characters' do
        service = described_class.new(component, 'a')
        result = service.find

        expect(result[:total_matches]).to eq(0)
      end

      it 'handles special regex characters safely' do
        create(:rule, component: component, rule_id: 'SV-004',
                      fixtext: 'Use pattern [a-z]+ for matching')
        service = described_class.new(component, '[a-z]+')
        result = service.find

        expect(result[:total_rules]).to eq(1)
        expect(result[:matches].first[:rule_identifier]).to eq('SV-004')
      end
    end
  end

  describe '#replace_instance' do
    it 'replaces a single instance at the specified index' do
      service = described_class.new(component, 'sshd')
      result = service.replace_instance(
        rule_id: rule1.id,
        field: 'fixtext',
        instance_index: 0,
        replacement: 'openssh-daemon',
        audit_comment: 'Standardize naming'
      )

      expect(result[:success]).to be true
      expect(result[:rule].fixtext).to include('openssh-daemon')
      # Second 'sshd' should still be there
      expect(result[:rule].fixtext).to include('sshd')
    end

    it 'returns error for non-existent rule' do
      service = described_class.new(component, 'sshd')
      result = service.replace_instance(
        rule_id: 99_999,
        field: 'fixtext',
        instance_index: 0,
        replacement: 'test'
      )

      expect(result[:success]).to be false
      expect(result[:error]).to eq('Rule not found')
    end

    it 'returns error for invalid field' do
      service = described_class.new(component, 'sshd')
      result = service.replace_instance(
        rule_id: rule1.id,
        field: 'invalid_field',
        instance_index: 0,
        replacement: 'test'
      )

      expect(result[:success]).to be false
      expect(result[:error]).to eq('Invalid field')
    end

    it 'returns error for out-of-bounds instance index' do
      service = described_class.new(component, 'sshd')
      result = service.replace_instance(
        rule_id: rule1.id,
        field: 'fixtext',
        instance_index: 99,
        replacement: 'test'
      )

      expect(result[:success]).to be false
      expect(result[:error]).to eq('Instance not found')
    end

    it 'creates audit trail' do
      service = described_class.new(component, 'sshd')

      expect do
        service.replace_instance(
          rule_id: rule1.id,
          field: 'fixtext',
          instance_index: 0,
          replacement: 'openssh',
          audit_comment: 'Test replacement'
        )
      end.to change { rule1.audits.count }.by_at_least(1)
    end
  end

  describe '#replace_field' do
    it 'replaces all instances in a single field' do
      service = described_class.new(component, 'sshd')
      result = service.replace_field(
        rule_id: rule1.id,
        field: 'fixtext',
        replacement: 'openssh-server',
        audit_comment: 'Bulk replace in field'
      )

      expect(result[:success]).to be true
      expect(result[:replaced_count]).to eq(2) # fixtext has 2 occurrences
      expect(result[:rule].fixtext).not_to include('sshd')
      expect(result[:rule].fixtext.scan('openssh-server').size).to eq(2)
    end

    it 'returns replaced count' do
      service = described_class.new(component, 'sshd')
      result = service.replace_field(
        rule_id: rule1.id,
        field: 'fixtext',
        replacement: 'new-daemon'
      )

      expect(result[:replaced_count]).to eq(2)
    end
  end

  describe '#replace_all' do
    it 'replaces all matches across all rules in the component' do
      service = described_class.new(component, 'sshd')
      result = service.replace_all(
        replacement: 'secure-shell-daemon',
        audit_comment: 'Global standardization'
      )

      expect(result[:success]).to be true
      expect(result[:rules_updated]).to eq(2) # rule1 and rule2 have 'sshd'
      expect(result[:matches_replaced]).to be >= 4

      # Verify rules are actually updated
      rule1.reload
      rule2.reload
      expect(rule1.fixtext).not_to include('sshd')
      expect(rule2.fixtext).not_to include('sshd')
    end

    it 'performs all updates in a transaction' do
      service = described_class.new(component, 'sshd')

      # Mock an error on the second rule to test transaction rollback
      allow_any_instance_of(Rule).to receive(:update!).and_wrap_original do |method, *args|
        # First call succeeds, subsequent calls fail
        @call_count ||= 0
        @call_count += 1
        raise ActiveRecord::RecordInvalid if @call_count > 2

        method.call(*args)
      end

      result = service.replace_all(replacement: 'test')

      # Transaction should have rolled back, original content preserved
      expect(result[:success]).to be false
    end

    it 'respects field filtering' do
      service = described_class.new(component, 'sshd', fields: ['title'])
      result = service.replace_all(replacement: 'openssh')

      expect(result[:rules_updated]).to eq(1) # Only rule1 has 'sshd' in title
      rule1.reload
      expect(rule1.title).to include('openssh')
      expect(rule1.fixtext).to include('sshd') # fixtext unchanged
    end
  end

  describe '#undo' do
    it 'reverts the last Find & Replace change' do
      # First, make a replacement
      service = described_class.new(component, 'sshd')
      original_fixtext = rule1.fixtext.dup
      service.replace_instance(
        rule_id: rule1.id,
        field: 'fixtext',
        instance_index: 0,
        replacement: 'openssh-daemon',
        audit_comment: 'Find & Replace - test'
      )

      rule1.reload
      expect(rule1.fixtext).to include('openssh-daemon')

      # Now undo it
      undo_service = described_class.new(component, '')
      result = undo_service.undo(rule_id: rule1.id)

      expect(result[:success]).to be true
      expect(result[:reverted_fields]).to include('fixtext')
      expect(result[:rule].fixtext).to eq(original_fixtext)
    end

    it 'returns error for non-existent rule' do
      service = described_class.new(component, '')
      result = service.undo(rule_id: 99_999)

      expect(result[:success]).to be false
      expect(result[:error]).to eq('Rule not found')
    end

    it 'returns error when nothing to undo' do
      # Rule has no Find & Replace audits
      service = described_class.new(component, '')
      result = service.undo(rule_id: rule3.id)

      expect(result[:success]).to be false
      expect(result[:error]).to eq('Nothing to undo')
    end

    it 'only undoes Find & Replace operations' do
      # Make a non-Find & Replace change
      rule1.update!(fixtext: 'Manual change', audit_comment: 'Manual edit')

      # Then make a Find & Replace change
      replace_service = described_class.new(component, 'Manual')
      replace_service.replace_instance(
        rule_id: rule1.id,
        field: 'fixtext',
        instance_index: 0,
        replacement: 'Automatic',
        audit_comment: 'Find & Replace - test'
      )

      rule1.reload
      expect(rule1.fixtext).to eq('Automatic change')

      # Undo should revert to 'Manual change', not original fixtext
      undo_service = described_class.new(component, '')
      result = undo_service.undo(rule_id: rule1.id)

      expect(result[:success]).to be true
      expect(result[:rule].fixtext).to eq('Manual change')
    end

    it 'creates an audit trail for the undo operation' do
      # First, make a replacement
      service = described_class.new(component, 'sshd')
      service.replace_instance(
        rule_id: rule1.id,
        field: 'fixtext',
        instance_index: 0,
        replacement: 'openssh-daemon',
        audit_comment: 'Find & Replace - test'
      )

      # Now undo it and check audit trail
      undo_service = described_class.new(component, '')
      expect do
        undo_service.undo(rule_id: rule1.id)
      end.to change { rule1.audits.count }.by_at_least(1)

      # Last audit should be the undo
      rule1.reload
      last_audit = rule1.audits.last
      expect(last_audit.comment).to eq('Find & Replace - Undo')
    end
  end

  describe 'performance', :performance do
    it 'handles large components efficiently' do
      # Create 200 rules
      200.times do |i|
        create(:rule, component: component, rule_id: "SV-#{i + 100}",
                      fixtext: "Configure the sshd service on server #{i}.")
      end

      service = described_class.new(component, 'sshd')

      # Find should complete in reasonable time
      start_time = Time.current
      result = service.find
      elapsed = Time.current - start_time

      expect(result[:total_rules]).to be >= 200
      expect(elapsed).to be < 2.seconds # Should be fast
    end
  end
end
