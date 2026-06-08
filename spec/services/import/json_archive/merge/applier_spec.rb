# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::JsonArchive::Merge::Applier, type: :service do
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
end
