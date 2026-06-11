# frozen_string_literal: true

require 'rails_helper'
require 'zip'
require 'stringio'

RSpec.describe Import::JsonArchive::Merge::Orchestrator, type: :service do
  before do
    allow(Import::JsonArchive::Merge::SnapshotManager).to receive_messages(
      create_snapshot: '/tmp/orchestrator_snapshot.zip',
      rotate_snapshots: nil
    )
  end

  let(:component) { create(:component, :closed_comment_phase) }
  let(:actor) { create(:user, email: 'orchestrator-actor@test.org') }

  # Build a valid backup-shape zip in-memory from a live component,
  # optionally mutating the serialized data before writing.
  def zip_bytes_from(component, mutations: nil)
    data = Export::Serializers::BackupSerializer.new(component).serialize.deep_stringify_keys
    mutations&.call(data)
    manifest = { 'backup_format_version' => '1.1', 'vulcan_version' => 'test', 'components' => [] }

    Zip::OutputStream.write_buffer do |zio|
      zio.put_next_entry('manifest.json')
      zio.write(manifest.to_json)
      zio.put_next_entry('component.json')
      zio.write(data['component'].to_json)
      zio.put_next_entry('rules.json')
      zio.write(data['rules'].to_json)
      zio.put_next_entry('satisfactions.json')
      zio.write(data['satisfactions'].to_json)
      zio.put_next_entry('reviews.json')
      zio.write(data['reviews'].to_json)
    end.string
  end

  describe '#call — happy path' do
    it 'parses, analyzes, and applies a clean archive returning a success result' do
      bytes = zip_bytes_from(component)

      result = described_class.new(
        archive_bytes: bytes, component: component, actor: actor
      ).call

      expect(result).to be_a(Import::JsonArchive::Merge::MergeResult)
      expect(result.success?).to be(true)
      expect(result.summary).to be_present
      expect(ComponentSyncEvent.where(component: component, status: 'applied').count).to eq(1)
    end
  end

  describe '#call — analyze precondition failure' do
    it 'returns a failed MergeResult with structured_error step :analyze and never calls Applier' do
      bytes = zip_bytes_from(
        component,
        mutations: lambda do |d|
          # Self-referencing review external_id == responding_to → Analyzer
          # raises PreconditionError before any apply.
          d['reviews'] << {
            'external_id' => 4242, 'rule_id' => d['rules'].first['rule_id'],
            'comment' => 'self-ref', 'created_at' => '2026-06-08T10:00:00.000000',
            'responding_to_external_id' => 4242
          }
        end
      )

      expect(Import::JsonArchive::Merge::Applier).not_to receive(:new)

      result = described_class.new(
        archive_bytes: bytes, component: component, actor: actor
      ).call

      expect(result.success?).to be(false)
      steps = result.structured_errors.map(&:step)
      expect(steps).to include(:analyze)
      expect(result.errors.first).to include('self-referencing')
    end
  end

  describe '#call — strategy_overrides forwarding' do
    it 'propagates overrides to the constructed Strategy used by Analyzer' do
      target_rule = component.rules.first
      bytes = zip_bytes_from(
        component,
        mutations: lambda do |d|
          row = d['rules'].find { |r| r['rule_id'] == target_rule.rule_id }
          row['fixtext'] = 'THEIRS edited fixtext'
        end
      )

      result = described_class.new(
        archive_bytes: bytes, component: component, actor: actor,
        strategy_overrides: { rule: { 'fixtext' => :theirs } }
      ).call

      expect(result.success?).to be(true)
      expect(target_rule.reload.fixtext).to eq('THEIRS edited fixtext')
      expect(
        MergeOperation.where(entity_type: 'rule', field_name: 'fixtext', operation: 'update').count
      ).to eq(1)
    end
  end

  describe '#call — actor forwarding to Applier' do
    it 'does not emit the missing-actor warning when actor is present' do
      bytes = zip_bytes_from(component)

      result = described_class.new(
        archive_bytes: bytes, component: component, actor: actor
      ).call

      expect(result.success?).to be(true)
      expect(result.warnings.to_a.join(' ')).not_to include('actor not provided')
    end

    it 'emits the missing-actor warning when actor is nil for source=theirs' do
      bytes = zip_bytes_from(component)

      result = described_class.new(
        archive_bytes: bytes, component: component, actor: nil
      ).call

      expect(result.success?).to be(true)
      expect(result.warnings.to_a.join(' ')).to include('actor not provided')
    end
  end

  describe '#call — blank archive_bytes' do
    it 'returns a failed MergeResult with structured_error step :parse' do
      result = described_class.new(
        archive_bytes: '', component: component, actor: actor
      ).call

      expect(result.success?).to be(false)
      expect(result.structured_errors.map(&:step)).to include(:parse)
    end

    it 'returns a failed MergeResult when archive_bytes is nil' do
      result = described_class.new(
        archive_bytes: nil, component: component, actor: actor
      ).call

      expect(result.success?).to be(false)
      expect(result.structured_errors.map(&:step)).to include(:parse)
    end
  end

  describe '#call — corrupt archive_bytes' do
    it 'captures the zip parse failure as a structured_error step :parse' do
      result = described_class.new(
        archive_bytes: 'not a zip file', component: component, actor: actor
      ).call

      expect(result.success?).to be(false)
      expect(result.structured_errors.map(&:step)).to include(:parse)
    end
  end

  describe '#call — SignatureGate integration' do
    it 'returns a failed MergeResult with step :signature when the gate is on and no signature is present' do
      allow(Import::JsonArchive::Merge::SignatureGate).to receive(:required?).and_return(true)
      bytes = zip_bytes_from(component) # manifest has no signature field

      result = described_class.new(
        archive_bytes: bytes, component: component, actor: actor
      ).call

      expect(result.success?).to be(false)
      expect(result.structured_errors.map(&:step)).to include(:signature)
    end

    it 'passes through when the gate is off (default)' do
      bytes = zip_bytes_from(component)

      result = described_class.new(
        archive_bytes: bytes, component: component, actor: actor
      ).call

      expect(result.success?).to be(true)
    end
  end
end
