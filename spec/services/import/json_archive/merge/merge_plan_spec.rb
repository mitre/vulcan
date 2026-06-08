# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::JsonArchive::Merge::MergePlan, type: :service do
  let(:plan) { described_class.new(component_id: 1, strategy: 'default', manifest: { 'backup_format_version' => '1.1' }) }

  describe '#summary' do
    it 'starts with zero counts across all entities' do
      expect(plan.summary).to include(
        'rules' => { 'matched' => 0, 'only_ours' => 0, 'only_theirs' => 0 },
        'reviews' => { 'matched' => 0, 'only_ours' => 0, 'only_theirs' => 0 },
        'satisfactions' => { 'matched' => 0, 'only_ours' => 0, 'only_theirs' => 0 },
        'memberships' => { 'matched' => 0, 'only_ours' => 0, 'only_theirs' => 0 }
      )
    end
  end

  describe '#add_rule_partition' do
    it 'records counts for rule matched/only_ours/only_theirs' do
      plan.add_rule_partition(matched: [1, 2, 3], only_ours: [], only_theirs: [4])
      expect(plan.summary['rules']).to eq('matched' => 3, 'only_ours' => 0, 'only_theirs' => 1)
    end
  end

  describe 'partition record accessors' do
    it 'exposes the actual records (not just counts) so the applier can act on them' do
      reviews_matched = [{ 'external_id' => 1 }, { 'external_id' => 2 }]
      reviews_theirs = [{ 'external_id' => 99 }]
      plan.add_review_partition(matched: reviews_matched, only_ours: [], only_theirs: reviews_theirs)

      expect(plan.matched_reviews).to eq(reviews_matched)
      expect(plan.only_theirs_reviews).to eq(reviews_theirs)
      expect(plan.only_ours_reviews).to eq([])
    end

    it 'summary counts agree with the underlying record arrays' do
      plan.add_rule_partition(matched: [1, 2, 3], only_ours: [4], only_theirs: [5, 6])

      expect(plan.summary['rules']).to eq('matched' => 3, 'only_ours' => 1, 'only_theirs' => 2)
      expect(plan.matched_rules.size).to eq(3)
      expect(plan.only_theirs_rules.size).to eq(2)
    end
  end

  describe '#validate_partition_invariant!' do
    it 'passes when sides are internally consistent' do
      plan.add_rule_partition(matched: [1, 2], only_ours: [3], only_theirs: [4])
      expect { plan.validate_partition_invariant!(:rules, ours_count: 3, theirs_count: 3) }.not_to raise_error
    end

    it 'raises when matched + only_ours != ours_count' do
      plan.add_rule_partition(matched: [1], only_ours: [], only_theirs: [])
      expect { plan.validate_partition_invariant!(:rules, ours_count: 2, theirs_count: 1) }
        .to raise_error(Import::JsonArchive::Merge::MergePlan::PartitionInvariantError, /rules/)
    end

    it 'raises when matched + only_theirs != theirs_count' do
      plan.add_rule_partition(matched: [1], only_ours: [], only_theirs: [])
      expect { plan.validate_partition_invariant!(:rules, ours_count: 1, theirs_count: 2) }
        .to raise_error(Import::JsonArchive::Merge::MergePlan::PartitionInvariantError, /rules/)
    end
  end

  describe '#add_resolution_log_entry' do
    it 'accepts a Hash{String=>String} entry' do
      plan.add_resolution_log_entry(entry: { 'rule_id' => 'V-1', 'field' => 'title', 'resolution' => 'auto_theirs' })
      expect(plan.resolution_log.first).to eq('rule_id' => 'V-1', 'field' => 'title', 'resolution' => 'auto_theirs')
    end

    it 'rejects symbol keys (string-only per F19)' do
      expect { plan.add_resolution_log_entry(entry: { rule_id: 'V-1' }) }
        .to raise_error(ArgumentError, /string keys/i)
    end

    it 'rejects symbol or non-string values' do
      expect { plan.add_resolution_log_entry(entry: { 'rule_id' => :v1 }) }
        .to raise_error(ArgumentError, /string values/i)
    end

    it 'caps resolution_log at MAX_RESOLUTION_LOG_ENTRIES (F16 DOS guard)' do
      stub_const("#{described_class.name}::MAX_RESOLUTION_LOG_ENTRIES", 3)
      3.times { |i| plan.add_resolution_log_entry(entry: { 'i' => i.to_s }) }
      expect { plan.add_resolution_log_entry(entry: { 'i' => '4' }) }
        .to raise_error(Import::JsonArchive::Merge::MergePlan::ResolutionLogOverflowError)
    end
  end

  describe '#resolution_log' do
    it 'returns a frozen view (callers can not mutate the internal log)' do
      plan.add_resolution_log_entry(entry: { 'k' => 'v' })
      expect(plan.resolution_log).to be_frozen
    end
  end

  describe '#conflicts / #auto_merged / #skipped' do
    it 'partitions FieldChanges by resolution category' do
      auto = Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
        field: 'title', from: 'A', to: 'B', resolution: :auto_theirs, locked: false, reason: ''
      )
      conflict = Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
        field: 'fixtext', from: 'A', to: 'B', resolution: :conflict, locked: false, reason: ''
      )
      locked = Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
        field: 'check_content', from: 'A', to: 'B', resolution: :locked_conflict, locked: true, reason: ''
      )

      plan.add_field_changes('V-1', [auto, conflict, locked])

      expect(plan.auto_merged.map(&:field)).to eq(['title'])
      expect(plan.conflicts.map(&:field)).to contain_exactly('fixtext', 'check_content')
    end
  end
end
