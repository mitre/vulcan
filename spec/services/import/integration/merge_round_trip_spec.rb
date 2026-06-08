# frozen_string_literal: true

require 'rails_helper'

# End-to-end pipeline coverage for the merge engine:
#
#   live component → BackupSerializer (theirs archive) → MergeInput
#                  → Analyzer.call → MergePlan
#                  → Applier.call → DB writes
#                  → assert receiving component now matches expected post-merge state
#
# These specs are the safety net against regressions anywhere in the
# 11-commit Analyzer chain + 13-commit Applier chain. Failures here
# indicate a contract drift between pieces that pass their own unit
# specs in isolation.
RSpec.describe 'Merge engine round-trip (Analyzer + Applier)', type: :service do
  before do
    allow(Import::JsonArchive::Merge::SnapshotManager)
      .to receive(:create_snapshot).and_return('/tmp/merge_round_trip_snapshot.zip')
  end

  let(:component) { create(:component, :closed_comment_phase) }
  let(:strategy) do
    # Override fixtext to :theirs so the round-trip applies the divergence
    # we deliberately introduce below.
    Import::JsonArchive::Merge::Strategy.new(overrides: { rule: { 'fixtext' => :theirs } })
  end
  let(:manifest) { { 'backup_format_version' => '1.1' } }

  def serialize(component)
    Export::Serializers::BackupSerializer.new(component).serialize
  end

  describe 'simple auto-merge round-trip (1 rule field flipped on theirs)' do
    it 'analyze → apply leaves the receiving component holding theirs value' do
      target_rule = component.rules.first
      theirs_data = serialize(component).deep_stringify_keys
      target_row = theirs_data['rules'].find { |r| r['rule_id'] == target_rule.rule_id }
      target_row['fixtext'] = 'THEIRS edited value'
      theirs_input = Import::JsonArchive::Merge::MergeInput.from_json_archive(theirs_data, manifest: manifest)

      plan = Import::JsonArchive::Merge::Analyzer.new(
        merge_input: theirs_input, component: component, strategy: strategy, manifest: manifest
      ).call

      expect(plan.auto_merged.map(&:field)).to include('fixtext')

      result = Import::JsonArchive::Merge::Applier.new(
        merge_plan: plan, component: component, source: 'theirs', archive_bytes: 'round-trip-bytes'
      ).call

      expect(result.success?).to be(true)
      expect(target_rule.reload.fixtext).to eq('THEIRS edited value')
      expect(MergeOperation.where(entity_type: 'rule', field_name: 'fixtext').count).to eq(1)
    end
  end

  describe 'locked-section conflict round-trip (Scenario C tripwire)' do
    it 'analyzes → conflict → applier DOES NOT write the field; the lock holds' do
      target_rule = component.rules.first
      target_rule.update_columns(locked_fields: { 'Check' => true })
      original_check = target_rule.checks.first.content
      theirs_data = serialize(component.reload).deep_stringify_keys
      target_row = theirs_data['rules'].find { |r| r['rule_id'] == target_rule.rule_id }
      target_row['locked_fields'] = {} # theirs is unlocked
      target_row['checks'].first['content'] = 'THEIRS edited check content (locked → blocked)'
      theirs_input = Import::JsonArchive::Merge::MergeInput.from_json_archive(theirs_data, manifest: manifest)

      plan = Import::JsonArchive::Merge::Analyzer.new(
        merge_input: theirs_input, component: component, strategy: strategy, manifest: manifest
      ).call

      expect(plan.conflicts.map(&:resolution)).to include(:locked_conflict)

      Import::JsonArchive::Merge::Applier.new(
        merge_plan: plan, component: component, source: 'theirs', archive_bytes: 'round-trip-bytes'
      ).call

      expect(target_rule.checks.first.reload.content).to eq(original_check)
      expect(MergeOperation.where(entity_type: 'rule', operation: 'skip').count).to be > 0
    end
  end

  describe 'satisfaction round-trip' do
    let(:satisfier) { component.rules.first }
    let(:satisfied) { component.rules.second }

    it 'analyzes a new satisfaction in theirs and applier persists it' do
      theirs_data = serialize(component).deep_stringify_keys
      theirs_data['satisfactions'] << {
        'rule_id' => satisfied.rule_id, 'satisfied_by_rule_id' => satisfier.rule_id
      }
      theirs_input = Import::JsonArchive::Merge::MergeInput.from_json_archive(theirs_data, manifest: manifest)

      plan = Import::JsonArchive::Merge::Analyzer.new(
        merge_input: theirs_input, component: component, strategy: strategy, manifest: manifest
      ).call

      expect(plan.summary['satisfactions']['only_theirs']).to eq(1)

      Import::JsonArchive::Merge::Applier.new(
        merge_plan: plan, component: component, source: 'theirs', archive_bytes: 'round-trip-bytes'
      ).call

      expect(RuleSatisfaction.find_by(rule_id: satisfied.id, satisfied_by_rule_id: satisfier.id)).not_to be_nil
    end
  end

  describe 'only_theirs review with reactions round-trip' do
    it 'analyze → apply imports the new comment review AND its reactions' do
      target_rule = component.rules.first
      reactor_up = create(:user, email: 'merge-react-up@test.org', name: 'Up Reactor')
      reactor_down = create(:user, email: 'merge-react-down@test.org', name: 'Down Reactor')

      theirs_data = serialize(component).deep_stringify_keys
      theirs_data['reviews'] << {
        'external_id' => 9999, 'rule_id' => target_rule.rule_id,
        'action' => 'comment', 'comment' => 'merge-side new comment',
        'created_at' => Time.zone.local(2026, 6, 8, 12, 0).iso8601(6),
        'user_email' => reactor_up.email, 'user_name' => reactor_up.name,
        'reactions' => [
          { 'kind' => 'up', 'user_email' => reactor_up.email,
            'created_at' => Time.zone.local(2026, 6, 8, 12, 1).iso8601(6) },
          { 'kind' => 'down', 'user_email' => reactor_down.email,
            'created_at' => Time.zone.local(2026, 6, 8, 12, 2).iso8601(6) }
        ]
      }
      Membership.create!(user: reactor_up, membership: component.project, role: 'viewer')

      theirs_input = Import::JsonArchive::Merge::MergeInput.from_json_archive(theirs_data, manifest: manifest)
      plan = Import::JsonArchive::Merge::Analyzer.new(
        merge_input: theirs_input, component: component, strategy: strategy, manifest: manifest
      ).call

      Import::JsonArchive::Merge::Applier.new(
        merge_plan: plan, component: component, source: 'theirs', archive_bytes: 'round-trip-bytes'
      ).call

      imported = Review.where(rule_id: target_rule.id, comment: 'merge-side new comment').first
      expect(imported).not_to be_nil
      tuples = imported.reactions.includes(:user).map { |r| [r.kind, r.user&.email] }.sort
      expect(tuples).to contain_exactly(['down', reactor_down.email], ['up', reactor_up.email])
    end
  end

  describe 'sync metadata' do
    it 'after a successful merge, component.last_sync_id matches the latest sync_event.sync_id' do
      theirs_input = Import::JsonArchive::Merge::MergeInput.from_json_archive(serialize(component), manifest: manifest)
      plan = Import::JsonArchive::Merge::Analyzer.new(
        merge_input: theirs_input, component: component, strategy: strategy, manifest: manifest
      ).call

      Import::JsonArchive::Merge::Applier.new(
        merge_plan: plan, component: component, source: 'theirs', archive_bytes: 'round-trip-bytes'
      ).call

      expect(component.reload.last_sync_id).to eq(ComponentSyncEvent.last.sync_id)
    end
  end
end
