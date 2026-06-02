# frozen_string_literal: true

require 'rails_helper'

# pre-merge snapshot lifecycle. Each merge writes
# a full component backup zip with a SHA-256 checksum alongside; recovery
# (Phase 2d) verifies the checksum before restore.
RSpec.describe Import::JsonArchive::Merge::SnapshotManager do
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project) }

  # Settings is Settingslogic — assignment raises MissingSetting on unknown
  # keys, so the stub-in-before pattern is the right idiom. `allow` inside
  # `before` IS within the per-test mock lifecycle (the `around`-based stub
  # is what's not allowed).
  before do
    @tmp = Dir.mktmpdir('snapshot-spec')
    allow(Settings.sync).to receive(:snapshot_path).and_return(@tmp)
  end

  after { FileUtils.remove_entry(@tmp) if @tmp && File.exist?(@tmp) }

  describe '.create_snapshot' do
    it 'writes a zip + matching .sha256 checksum file under the component dir' do
      path = described_class.create_snapshot(component)
      expect(File.exist?(path)).to be(true)
      expect(File.exist?("#{path}.sha256")).to be(true)

      recorded = File.read("#{path}.sha256").strip
      actual   = Digest::SHA256.hexdigest(File.binread(path))
      expect(recorded).to eq(actual)
    end

    it 'creates the per-component directory with mode 0700' do
      described_class.create_snapshot(component)
      dir = File.join(@tmp, component.id.to_s)
      expect(File.exist?(dir)).to be(true)
      # File.stat#mode includes the file type bits; mask to permission bits.
      expect(File.stat(dir).mode & 0o777).to eq(0o700)
    end
  end

  describe '.verify_snapshot' do
    it 'returns true for a snapshot whose checksum matches the zip' do
      path = described_class.create_snapshot(component)
      expect(described_class.verify_snapshot(path)).to be(true)
    end

    it 'returns false when the zip is tampered with after snapshot' do
      path = described_class.create_snapshot(component)
      File.binwrite(path, "#{File.binread(path)}garbage")
      expect(described_class.verify_snapshot(path)).to be(false)
    end
  end

  describe '.rotate_snapshots' do
    it 'keeps the N newest snapshots per component and deletes the rest (incl. .sha256)' do
      paths = []
      12.times do |i|
        # Time.current changes per call; bump mtime explicitly so ordering is
        # deterministic even when create_snapshot calls land in the same second.
        path = described_class.create_snapshot(component)
        bumped = (Time.current + i).to_time
        File.utime(bumped, bumped, path)
        paths << path
      end

      described_class.rotate_snapshots(component, keep: 10)

      remaining = Dir[File.join(@tmp, component.id.to_s, '*.zip')]
      expect(remaining.size).to eq(10)
      # The two oldest by mtime should be gone, with their checksum files.
      expect(remaining).to include(*paths.last(10))
      expect(File.exist?(paths.first)).to be(false)
      expect(File.exist?("#{paths.first}.sha256")).to be(false)
    end

    it 'is a no-op when the component directory does not exist' do
      expect { described_class.rotate_snapshots(component) }.not_to raise_error
    end
  end
end
