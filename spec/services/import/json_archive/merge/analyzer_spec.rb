# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::JsonArchive::Merge::Analyzer, type: :service do
  let(:component) { create(:component, :closed_comment_phase) }
  let(:strategy) { Import::JsonArchive::Merge::Strategy.new }
  let(:manifest) { { 'backup_format_version' => '1.1' } }

  let(:base_archive) { build_backup_hash(component) }
  let(:merge_input) { Import::JsonArchive::Merge::MergeInput.from_json_archive(base_archive, manifest: manifest) }

  describe 'preconditions' do
    it 'does NOT require comment_phase=closed at analysis time (read-only delta, applier enforces)' do
      open_component = create(:component, :open_comment_period)
      open_archive = build_backup_hash(open_component)
      open_input = Import::JsonArchive::Merge::MergeInput.from_json_archive(open_archive, manifest: manifest)

      analyzer = described_class.new(merge_input: open_input, component: open_component,
                                     strategy: strategy, manifest: manifest)

      expect { analyzer.call }.not_to raise_error
    end

    it 'raises PreconditionError when reviews.size > 10_000 (CLI ceiling)' do
      huge_archive = base_archive.merge('reviews' => Array.new(10_001) { { 'rule_id' => 'V-1', 'comment' => 'x' } })
      huge_input = Import::JsonArchive::Merge::MergeInput.from_json_archive(huge_archive, manifest: manifest)

      analyzer = described_class.new(merge_input: huge_input, component: component,
                                     strategy: strategy, manifest: manifest)

      expect { analyzer.call }
        .to raise_error(Import::JsonArchive::Merge::PreconditionError, /10_?000|ceiling/i)
    end

    it 'raises PreconditionError when any review.created_at is more than 1.day in the future' do
      future = 2.days.from_now.iso8601(6)
      reviews = [{ 'rule_id' => 'V-1', 'comment' => 'x', 'created_at' => future, 'external_id' => 1 }]
      future_archive = base_archive.merge('reviews' => reviews)
      future_input = Import::JsonArchive::Merge::MergeInput.from_json_archive(future_archive, manifest: manifest)

      analyzer = described_class.new(merge_input: future_input, component: component,
                                     strategy: strategy, manifest: manifest)

      expect { analyzer.call }
        .to raise_error(Import::JsonArchive::Merge::PreconditionError, /future|timestamp/i)
    end

    it 'raises PreconditionError on self-referencing reviews (F17 — must catch BEFORE DFS)' do
      reviews = [{
        'rule_id' => 'V-1', 'comment' => 'x',
        'external_id' => 42, 'responding_to_external_id' => 42,
        'created_at' => Time.current.iso8601(6)
      }]
      self_ref_archive = base_archive.merge('reviews' => reviews)
      self_ref_input = Import::JsonArchive::Merge::MergeInput.from_json_archive(self_ref_archive, manifest: manifest)

      analyzer = described_class.new(merge_input: self_ref_input, component: component,
                                     strategy: strategy, manifest: manifest)

      expect { analyzer.call }
        .to raise_error(Import::JsonArchive::Merge::PreconditionError, /self-referenc/i)
    end

    it 'raises PreconditionError on cycles in responding_to chains' do
      now = Time.current.iso8601(6)
      reviews = [
        { 'rule_id' => 'V-1', 'comment' => 'a', 'external_id' => 1, 'responding_to_external_id' => 2, 'created_at' => now },
        { 'rule_id' => 'V-1', 'comment' => 'b', 'external_id' => 2, 'responding_to_external_id' => 1, 'created_at' => now }
      ]
      cyclic_archive = base_archive.merge('reviews' => reviews)
      cyclic_input = Import::JsonArchive::Merge::MergeInput.from_json_archive(cyclic_archive, manifest: manifest)

      analyzer = described_class.new(merge_input: cyclic_input, component: component,
                                     strategy: strategy, manifest: manifest)

      expect { analyzer.call }
        .to raise_error(Import::JsonArchive::Merge::PreconditionError, /cycle/i)
    end
  end

  describe '#call (happy path)' do
    it 'returns a MergePlan for identical ours/theirs (matched-all, no divergence)' do
      analyzer = described_class.new(merge_input: merge_input, component: component,
                                     strategy: strategy, manifest: manifest)

      plan = analyzer.call

      expect(plan).to be_an(Import::JsonArchive::Merge::MergePlan)
      expect(plan.summary['rules']['matched']).to eq(component.rules.count)
      expect(plan.summary['rules']['only_ours']).to eq(0)
      expect(plan.summary['rules']['only_theirs']).to eq(0)
      expect(plan.conflicts).to be_empty
    end

    it 'partitions reviews into matched / only_ours / only_theirs' do
      rule_id = component.rules.first.rule_id
      now = Time.current.iso8601(6)
      reviews = [
        { 'rule_id' => rule_id, 'comment' => 'theirs only', 'created_at' => now, 'external_id' => 99 }
      ]
      archive_with_review = base_archive.merge('reviews' => reviews)
      input = Import::JsonArchive::Merge::MergeInput.from_json_archive(archive_with_review, manifest: manifest)

      analyzer = described_class.new(merge_input: input, component: component, strategy: strategy, manifest: manifest)

      plan = analyzer.call
      expect(plan.summary['reviews']['matched']).to eq(0)
      expect(plan.summary['reviews']['only_ours']).to eq(0)
      expect(plan.summary['reviews']['only_theirs']).to eq(1)
    end

    it 'calls validate_partition_invariant! on every entity partition before returning' do
      analyzer = described_class.new(merge_input: merge_input, component: component,
                                     strategy: strategy, manifest: manifest)
      plan_spy = Import::JsonArchive::Merge::MergePlan.new(component_id: component.id, strategy: strategy, manifest: manifest)
      allow(Import::JsonArchive::Merge::MergePlan).to receive(:new).and_return(plan_spy)
      expect(plan_spy).to receive(:validate_partition_invariant!).at_least(:once).and_call_original

      analyzer.call
    end
  end

  describe 'v2-480.34: nested-only-side records surface to resolution_log' do
    it 'adds a nested_one_sided resolution_log entry for a Check on theirs only' do
      target_rule = component.rules.first
      theirs_data = base_archive.deep_stringify_keys
      theirs_data['rules'].find { |r| r['rule_id'] == target_rule.rule_id }['checks'] << {
        'system' => 'C.NEW-FROM-THEIRS', 'content' => 'new from theirs'
      }
      input = Import::JsonArchive::Merge::MergeInput.from_json_archive(theirs_data, manifest: manifest)
      analyzer = described_class.new(merge_input: input, component: component,
                                     strategy: strategy, manifest: manifest)

      plan = analyzer.call

      entries = plan.resolution_log.select { |e| e['type'] == 'nested_one_sided' }
      expect(entries.size).to be >= 1
      target_entry = entries.find { |e| JSON.parse(e['identity'])['system'] == 'C.NEW-FROM-THEIRS' }
      expect(target_entry).not_to be_nil
      expect(target_entry['side']).to eq('theirs_only')
      expect(target_entry['assoc']).to eq('checks')
    end
  end

  describe 'eager-load contract (no N+1 on rules/reviews/satisfies)' do
    def captured_sql(&)
      queries = []
      callback = lambda do |_n, _s, _f, _id, payload|
        queries << payload[:sql] unless payload[:name] == 'SCHEMA'
      end
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record', &)
      queries
    end

    let(:component_with_many_rules) do
      c = create(:component, :closed_comment_phase)
      3.times do |i|
        rule = create(:rule, component: c, rule_id: "V-100#{i}")
        2.times do |j|
          create(:review, rule: rule, user: create(:user),
                          action: 'comment', comment: "c#{i}-#{j}")
        end
      end
      c
    end

    it 'fires SELECT FROM reviews exactly once for the full pipeline (not N times)' do
      input = Import::JsonArchive::Merge::MergeInput.from_json_archive(
        build_backup_hash(component_with_many_rules), manifest: manifest
      )
      analyzer = described_class.new(merge_input: input, component: component_with_many_rules,
                                     strategy: strategy, manifest: manifest)

      sql = captured_sql { analyzer.call }
      review_selects = sql.grep(/SELECT.*FROM .reviews./i)
      expect(review_selects.size).to be <= 1
    end

    it 'fires SELECT FROM rule_satisfactions a bounded number of times (satisfies + satisfied_by, not N+1)' do
      input = Import::JsonArchive::Merge::MergeInput.from_json_archive(
        build_backup_hash(component_with_many_rules), manifest: manifest
      )
      analyzer = described_class.new(merge_input: input, component: component_with_many_rules,
                                     strategy: strategy, manifest: manifest)

      sql = captured_sql { analyzer.call }
      sat_selects = sql.grep(/SELECT.*FROM .rule_satisfactions./i)
      # eager-load preloads :satisfies and :satisfied_by — 2 IN(...) queries, not N+1
      expect(sat_selects.size).to be <= 2
    end
  end
end
