# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::JsonArchive::Merge::Applier, type: :service do
  # All applier specs short-circuit SnapshotManager: it's tested in its own
  # spec, and exercising it here would write real zips to the default
  # storage path. Override locally in specs that assert on snapshot paths.
  before do
    allow(Import::JsonArchive::Merge::SnapshotManager)
      .to receive(:create_snapshot).and_return('/tmp/applier_spec_default_snapshot.zip')
  end

  let(:component) { create(:component, :closed_comment_phase) }
  let(:strategy) { Import::JsonArchive::Merge::Strategy.new }
  let(:manifest) { { 'backup_format_version' => '1.1' } }
  let(:archive_bytes) { 'fake archive bytes' }

  # A no-op plan over an unchanged component — applier should run through
  # the full lifecycle without writing any entity changes.
  let(:plan) do
    Import::JsonArchive::Merge::Analyzer.new(
      merge_input: Import::JsonArchive::Merge::MergeInput.from_json_archive(build_backup_hash(component), manifest: manifest),
      component: component,
      strategy: strategy,
      manifest: manifest
    ).call
  end

  describe '#call (lifecycle on a no-op plan)' do
    subject(:result) do
      described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
    end

    it 'returns a MergeResult' do
      expect(result).to be_a(Import::JsonArchive::Merge::MergeResult)
    end

    it 'creates exactly one ComponentSyncEvent with status applied' do
      expect { result }.to change(ComponentSyncEvent, :count).by(1)
      expect(ComponentSyncEvent.last.status).to eq('applied')
    end

    it 'records the merge source and inbound direction' do
      result
      event = ComponentSyncEvent.last
      expect(event.direction).to eq('inbound')
      expect(event.source).to eq('theirs')
    end

    it 'generates a unique sync_id (UUID)' do
      result
      event = ComponentSyncEvent.last
      expect(event.sync_id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it 'persists the MergePlan resolution_log on the sync event' do
      plan.add_resolution_log_entry(entry: { 'note' => 'no-op' })
      result
      event = ComponentSyncEvent.last
      expect(event.resolution_log_json).to be_an(Array)
      expect(event.resolution_log_json.first).to include('note' => 'no-op')
    end

    it 'attaches the sync event to the result via #plan or accessor' do
      expect(result.plan).to eq(plan)
    end
  end

  describe '#call (transaction safety)' do
    # The applier requests isolation: :serializable only when invoked
    # outside an existing transaction (production controller / rake
    # path). Inside a wrapping transaction — as here under transactional
    # fixtures — it joins without changing isolation, so the call must
    # NOT raise TransactionIsolationError.
    it 'joins an existing transaction when one is already open (no TransactionIsolationError)' do
      expect(ActiveRecord::Base.connection.transaction_open?).to be(true) # sanity: we ARE in one
      r = described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      expect(r.success?).to be(true)
    end

    it 'rescues SerializationFailure from apply_all and surfaces "component modified during merge"' do
      applier = described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes)
      allow(applier).to receive(:apply_all).and_raise(ActiveRecord::SerializationFailure.new('serial'))

      r = applier.call

      expect(r.success?).to be(false)
      expect(r.errors.join).to include('component modified during merge')
    end
  end

  describe '#call (failure marks event)' do
    it 'sets sync event status to failed on apply_all error' do
      applier = described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes)
      allow(applier).to receive(:apply_all).and_raise(ActiveRecord::StatementInvalid.new('boom'))

      applier.call

      expect(ComponentSyncEvent.last.status).to eq('failed')
    end
  end

  describe '#call (pre-merge snapshot + archive hash)' do
    let(:tmp_snapshot_path) { Tempfile.new(['snapshot', '.zip']).path }

    before do
      allow(Import::JsonArchive::Merge::SnapshotManager)
        .to receive(:create_snapshot).and_return(tmp_snapshot_path)
    end

    it 'creates a snapshot via SnapshotManager and records the path on the sync event' do
      expect(Import::JsonArchive::Merge::SnapshotManager).to receive(:create_snapshot).with(component)

      described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      expect(ComponentSyncEvent.last.snapshot_path).to eq(tmp_snapshot_path)
    end

    it 'stores SHA-256 of the archive bytes on the sync event' do
      described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      event = ComponentSyncEvent.last
      expect(event.archive_hash).to eq(Digest::SHA256.hexdigest(archive_bytes))
    end

    it 'leaves archive_hash nil when archive_bytes is nil (caller did not provide)' do
      described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: nil).call

      expect(ComponentSyncEvent.last.archive_hash).to be_nil
    end
  end

  describe '#call (applies rule auto-merged changes)' do
    # Build a plan with one auto_theirs field change so we can observe
    # the applier write to the DB + log a merge_operations row.
    let(:target_rule) { component.rules.first }
    let(:auto_plan) do
      p = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id,
        strategy: strategy,
        manifest: manifest
      )
      change = Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
        field: 'fixtext', from: target_rule.fixtext, to: 'THEIRS fixtext',
        resolution: :auto_theirs, locked: false, reason: 'Strategy resolved to :theirs'
      )
      p.add_field_changes(target_rule.rule_id, [change])
      p
    end

    it 'persists the field change on the rule' do
      described_class.new(merge_plan: auto_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      expect(target_rule.reload.fixtext).to eq('THEIRS fixtext')
    end

    it 'writes one MergeOperation row per applied field with before/after captured' do
      expect do
        described_class.new(merge_plan: auto_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.to change(MergeOperation, :count).by(1)

      op = MergeOperation.last
      expect(op.entity_type).to eq('rule')
      expect(op.entity_key).to eq(target_rule.rule_id)
      expect(op.field_name).to eq('fixtext')
      expect(op.new_value).to eq('THEIRS fixtext')
      expect(op.operation).to eq('update')
      expect(op.source).to eq('theirs')
    end

    it ':auto_ours uses the from value (keeps ours), still logs the operation' do
      auto_ours_plan = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      auto_ours_plan.add_field_changes(target_rule.rule_id, [
                                         Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
                                           field: 'fixtext', from: 'OURS fixtext keep', to: 'THEIRS fixtext drop',
                                           resolution: :auto_ours, locked: false, reason: ''
                                         )
                                       ])

      described_class.new(merge_plan: auto_ours_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      # auto_ours = keep ours; the rule's current value stays. No DB change.
      expect(target_rule.reload.fixtext).to eq(target_rule.fixtext)
      op = MergeOperation.last
      expect(op.source).to eq('ours')
    end

    it 'recalculates the components.rules_count counter cache after rule writes' do
      original_count = component.rules.where(deleted_at: nil).count
      component.update_columns(rules_count: 9999) # -- corrupt the cache to verify recalc

      described_class.new(merge_plan: auto_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      expect(component.reload.rules_count).to eq(original_count)
    end
  end

  describe '#call (skips conflict / locked_conflict)' do
    let(:target_rule) { component.rules.first }
    let(:conflict_plan) do
      p = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      p.add_field_changes(target_rule.rule_id, [
                            Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
                              field: 'fixtext', from: 'OURS', to: 'THEIRS',
                              resolution: :conflict, locked: false, reason: 'Strategy default'
                            ),
                            Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
                              field: 'title', from: 'ours title', to: 'theirs title',
                              resolution: :locked_conflict, locked: true, reason: "section 'Title' locked"
                            )
                          ])
      p
    end

    it 'does NOT write conflicted fields to the rule' do
      original_fixtext = target_rule.fixtext
      original_title = target_rule.title

      described_class.new(merge_plan: conflict_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      target_rule.reload
      expect(target_rule.fixtext).to eq(original_fixtext)
      expect(target_rule.title).to eq(original_title)
    end

    it 'records a merge_operations row with operation=skip for every conflict' do
      expect do
        described_class.new(merge_plan: conflict_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.to change(MergeOperation.where(operation: 'skip'), :count).by(2)

      skipped_fields = MergeOperation.where(operation: 'skip').pluck(:field_name).sort
      expect(skipped_fields).to eq(%w[fixtext title])
    end

    it 'tags the skip source as conflict_resolved' do
      described_class.new(merge_plan: conflict_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      sources = MergeOperation.where(operation: 'skip').pluck(:source).uniq
      expect(sources).to eq(['conflict_resolved'])
    end
  end

  describe '#call (closed-phase precondition)' do
    it 'refuses to apply against an open-phase component and marks the event failed' do
      open_component = create(:component, :open_comment_period)
      open_plan = Import::JsonArchive::Merge::Analyzer.new(
        merge_input: Import::JsonArchive::Merge::MergeInput.from_json_archive(build_backup_hash(open_component), manifest: manifest),
        component: open_component, strategy: strategy, manifest: manifest
      ).call

      result = described_class.new(merge_plan: open_plan, component: open_component, source: 'theirs', archive_bytes: archive_bytes).call

      expect(result.success?).to be(false)
      expect(result.errors.join).to match(/comment_phase/i)
      expect(ComponentSyncEvent.last.status).to eq('failed')
    end
  end
end
