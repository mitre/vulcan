# frozen_string_literal: true

# Helpers for assembling backup-shape archive payloads in-memory from factory
# records. Used by merge engine specs (ReviewMatcher, MergeInput, Analyzer)
# to avoid checking in zip fixtures.
#
# Rake-task specs that need actual zip files build them via Tempfile +
# Export::Base; this module covers the hash-shape case only.
module JsonArchiveArchiveBuilder
  # Serialize a component into the canonical backup hash. Identical shape to
  # what Export::Serializers::BackupSerializer.new(component).serialize emits.
  def build_backup_hash(component, preloaded_rules: nil)
    Export::Serializers::BackupSerializer
      .new(component, preloaded_rules: preloaded_rules)
      .serialize
  end

  # Build "ours" and "theirs" backup hashes from the same component, then
  # apply the given block to "theirs" so specs can express divergences as
  # mutations rather than two parallel factory setups.
  def build_diverged_backup_hashes(component, &theirs_mutator)
    ours = build_backup_hash(component)
    theirs = build_backup_hash(component)
    theirs_mutator&.call(theirs)
    [ours, theirs]
  end
end

RSpec.configure do |config|
  config.include JsonArchiveArchiveBuilder, type: :service
  config.include JsonArchiveArchiveBuilder, file_path: %r{spec/services/import/merge|spec/services/import/json_archive/merge|spec/lib/tasks/sync}
end
