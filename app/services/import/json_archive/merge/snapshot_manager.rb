# frozen_string_literal: true

require 'digest'
require 'fileutils'

module Import
  module JsonArchive
    module Merge
      # Pre-merge backup of a component (full JSON archive zip) written to a
      # configurable on-disk path, with a SHA-256 checksum file alongside for
      # corruption detection at restore time. Phase 2a infrastructure
      # (vulcan-v3.x-480.7); MergeApplier (Phase 2b) writes a snapshot before
      # any destructive merge, and disaster-recovery rake tasks (Phase 2d)
      # restore from it.
      #
      # Layout: <Settings.sync.snapshot_path>/<component_id>/<YYYYMMDDTHHMMSSffffff>.zip
      #         + matching <…>.zip.sha256
      class SnapshotManager
        DEFAULT_RETENTION = 10
        DIR_MODE = 0o700

        # Write a snapshot zip + checksum for `component`. Returns the
        # absolute path of the zip on success.
        def self.create_snapshot(component)
          zip_data = Export::Base.new(
            exportable: component, mode: :backup, format: :json_archive
          ).call.data

          dir = component_dir(component)
          FileUtils.mkdir_p(dir, mode: DIR_MODE)
          # mkdir_p only sets mode on dirs it CREATES; if the parent existed
          # already it keeps its prior mode. Force-set on the component dir.
          File.chmod(DIR_MODE, dir)

          path = File.join(dir, "#{Time.current.utc.strftime('%Y%m%dT%H%M%S%6N')}.zip")
          File.binwrite(path, zip_data)
          File.write(checksum_path(path), Digest::SHA256.hexdigest(zip_data))
          path
        end

        # True iff the snapshot's recorded checksum matches the file on disk.
        # rubocop:disable Naming/PredicateMethod -- API name fixed by 480.7 AC
        def self.verify_snapshot(path)
          expected = File.read(checksum_path(path)).strip
          actual   = Digest::SHA256.hexdigest(File.binread(path))
          expected == actual
        end
        # rubocop:enable Naming/PredicateMethod

        # Keep the `keep` newest snapshots for `component`; delete older
        # ones (and their checksum files). No-op if the dir doesn't exist.
        def self.rotate_snapshots(component, keep: DEFAULT_RETENTION)
          dir = component_dir(component)
          return unless Dir.exist?(dir)

          zips = Dir[File.join(dir, '*.zip')].sort_by { |f| File.mtime(f) }.reverse
          zips.drop(keep).each do |zip|
            # rm_f is atomic + a no-op when the target is missing, so the
            # zip + checksum pair stays consistent even under concurrent rotations.
            FileUtils.rm_f(zip)
            FileUtils.rm_f(checksum_path(zip))
          end
        end

        def self.component_dir(component)
          File.join(Settings.sync.snapshot_path.to_s, component.id.to_s)
        end

        def self.checksum_path(zip_path)
          "#{zip_path}.sha256"
        end

        private_class_method :component_dir, :checksum_path
      end
    end
  end
end
