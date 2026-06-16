# frozen_string_literal: true

require 'digest'
require 'fileutils'

module Import
  module JsonArchive
    module Merge
      # Pre-merge backup of a component (full JSON archive zip) written to a
      # configurable on-disk path, with a SHA-256 checksum file alongside for
      # corruption detection at restore time. Phase 2a infrastructure
      # MergeApplier writes a snapshot before
      # any destructive merge, and disaster-recovery rake tasks (Phase 2d)
      # restore from it.
      #
      # Layout: <Settings.sync.snapshot_path>/<component_id>/<YYYYMMDDTHHMMSSffffff>.zip
      #         + matching <…>.zip.sha256
      class SnapshotManager
        DEFAULT_RETENTION = 10
        DIR_MODE = 0o700

        # Per-component byte ceiling. 0 / nil / missing setting = disabled.
        # When set, create_snapshot raises SnapshotTooLargeError before
        # writing any bytes — keeps the merge_snapshots disk partition from
        # filling on a runaway component.
        class SnapshotTooLargeError < StandardError; end

        # Write a snapshot zip + checksum for `component`. Returns the
        # absolute path of the zip on success.
        # Two-phase write: data lands in *.tmp first, then FileUtils.mv
        # atomically renames into place — a crash mid-write leaves only
        # *.tmp orphans, not a corrupt zip at the snapshot_path
        # the sync_event will eventually point at. ENOSPC / SystemCallError
        # paths cleanup the orphans before re-raising.
        def self.create_snapshot(component)
          zip_data = Export::Base.new(
            exportable: component, mode: :backup, format: :json_archive
          ).call.data

          enforce_byte_budget!(zip_data.bytesize)

          dir = component_dir(component)
          FileUtils.mkdir_p(dir, mode: DIR_MODE)
          # mkdir_p only sets mode on dirs it CREATES; if the parent existed
          # already it keeps its prior mode. Force-set on the component dir.
          File.chmod(DIR_MODE, dir)

          path = File.join(dir, "#{Time.current.utc.strftime('%Y%m%dT%H%M%S%6N')}.zip")
          write_atomic(path, zip_data)
          path
        end

        def self.write_atomic(path, zip_data)
          tmp_zip = "#{path}.tmp"
          tmp_sha = "#{checksum_path(path)}.tmp"
          File.binwrite(tmp_zip, zip_data)
          File.write(tmp_sha, Digest::SHA256.hexdigest(zip_data))
          FileUtils.mv(tmp_zip, path)
          FileUtils.mv(tmp_sha, checksum_path(path))
        rescue SystemCallError
          [tmp_zip, tmp_sha, path, checksum_path(path)].each { |p| FileUtils.rm_f(p) }
          raise
        end

        def self.enforce_byte_budget!(bytes)
          budget = Settings.sync.respond_to?(:max_snapshot_bytes_per_component) &&
                   Settings.sync.max_snapshot_bytes_per_component
          return if budget.nil? || budget.to_i <= 0
          return if bytes <= budget.to_i

          raise SnapshotTooLargeError,
                "snapshot size (#{bytes} bytes) exceeds per-component budget (#{budget.to_i} bytes) — " \
                'aborting merge before any disk write'
        end

        # True iff the snapshot's recorded checksum matches the file on disk.
        # Errno::ENOENT (missing zip OR missing checksum) returns false so
        # callers can treat it as "no valid snapshot" instead of crashing.
        def self.verify_snapshot(path)
          expected = File.read(checksum_path(path)).strip
          actual   = Digest::SHA256.hexdigest(File.binread(path))
          expected == actual
        rescue Errno::ENOENT
          false
        end

        # Keep the `keep` newest snapshots for `component`; delete older
        # ones (and their checksum files). No-op if the dir doesn't exist.
        # Deletion order: checksum FIRST, then zip — a crash mid-rotation
        # leaves the snapshot in "invalid checksum" state (caught by
        # verify_snapshot returning false) instead of "zip without
        # checksum" (which would silently look valid to a tolerant caller).
        def self.rotate_snapshots(component, keep: DEFAULT_RETENTION)
          dir = component_dir(component)
          return unless Dir.exist?(dir)

          zips = Dir[File.join(dir, '*.zip')].sort_by { |f| File.mtime(f) }.reverse
          zips.drop(keep).each do |zip|
            FileUtils.rm_f(checksum_path(zip))
            FileUtils.rm_f(zip)
          end
        end

        def self.component_dir(component)
          File.join(Settings.sync.snapshot_path.to_s, component.id.to_s)
        end

        def self.checksum_path(zip_path)
          "#{zip_path}.sha256"
        end

        private_class_method :component_dir, :checksum_path, :write_atomic, :enforce_byte_budget!
      end
    end
  end
end
