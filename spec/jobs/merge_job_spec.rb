# frozen_string_literal: true

require 'rails_helper'
require 'zip'
require 'tempfile'

RSpec.describe MergeJob do
  before do
    allow(Import::JsonArchive::Merge::SnapshotManager).to receive_messages(
      create_snapshot: '/tmp/merge_job_snapshot.zip',
      rotate_snapshots: nil
    )
  end

  let(:component) { create(:component, :closed_comment_phase) }
  let(:actor) { create(:user, email: 'merge-job-actor@test.org') }

  # Persistent path (not Tempfile) so the file survives until perform reads it.
  # The job is responsible for unlinking on success/failure.
  def write_zip(bytes)
    path = File.join(Dir.tmpdir, "merge_job_spec_#{SecureRandom.hex(6)}.zip")
    File.binwrite(path, bytes)
    path
  end

  def clean_archive_bytes
    data = Export::Serializers::BackupSerializer.new(component).serialize.deep_stringify_keys
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

  describe '#perform — happy path' do
    it 'runs the merge through the Orchestrator and returns a successful MergeResult' do
      path = write_zip(clean_archive_bytes)

      result = described_class.perform_now(
        component_id: component.id, archive_path: path, actor_id: actor.id
      )

      expect(result).to be_a(Import::JsonArchive::Merge::MergeResult)
      expect(result.success?).to be(true)
      expect(ComponentSyncEvent.where(component: component, status: 'applied').count).to eq(1)
    end

    it 'unlinks the archive file after a successful run' do
      path = write_zip(clean_archive_bytes)

      described_class.perform_now(
        component_id: component.id, archive_path: path, actor_id: actor.id
      )

      expect(File.exist?(path)).to be(false)
    end
  end

  describe '#perform — failure paths' do
    it 'returns a failed MergeResult with :parse step on corrupt bytes' do
      path = write_zip('not a zip')

      result = described_class.perform_now(
        component_id: component.id, archive_path: path, actor_id: actor.id
      )

      expect(result.success?).to be(false)
      expect(result.structured_errors.map(&:step)).to include(:parse)
    end

    it 'still unlinks the archive file on a parse failure' do
      path = write_zip('not a zip')

      described_class.perform_now(
        component_id: component.id, archive_path: path, actor_id: actor.id
      )

      expect(File.exist?(path)).to be(false)
    end
  end

  describe 'queue + retry configuration' do
    it 'is enqueued on the :merge queue' do
      expect(described_class.new.queue_name).to eq('merge')
    end

    it 'declares retry_on ActiveRecord::SerializationFailure' do
      # ActiveJob stores rescue handlers as [class_name_string, proc] tuples.
      handler_names = described_class.rescue_handlers.map(&:first)
      expect(handler_names).to include('ActiveRecord::SerializationFailure')
    end
  end
end
