# frozen_string_literal: true

# Background ActiveJob that runs a single inbound merge through the
# MergeOrchestrator. Persists progress via the ComponentSyncEvent the
# Applier creates internally; the job returns the MergeResult for
# callers that want to introspect synchronously (test specs, the
# controller's polling endpoint reads sync_event.status directly).
#
# Lifecycle: the controller writes the multipart upload to a Tempfile,
# enqueues this job with the path, and returns { job_id:, sync_event_id: }
# to the client. The Tempfile is deleted by the job after the orchestrator
# reads it so the upload doesn't linger on disk if the job fails or is
# retried. v2-480.9.
class MergeJob < ApplicationJob
  queue_as :merge

  # Transient DB serialization errors (40001) can bubble out of paths the
  # Applier hasn't wrapped — retry up to 3 times before giving up.
  retry_on ActiveRecord::SerializationFailure, attempts: 3, wait: :polynomially_longer

  # @param component_id [Integer] receiving Component
  # @param archive_path [String] filesystem path to the uploaded zip.
  #   Read once into memory; the file is unlinked on success.
  # @param actor_id [Integer] User.id of the operator authorizing the
  #   merge. Forwarded to Applier for per-record audit attribution.
  # @param strategy_overrides [Hash, nil] forwarded to Orchestrator's
  #   Strategy.new(overrides: ...)
  # @param source [String] 'theirs' (default) or 'auto_merge'
  # @return [Import::JsonArchive::Merge::MergeResult]
  def perform(component_id:, archive_path:, actor_id:, strategy_overrides: nil, source: 'theirs')
    component = Component.find(component_id)
    actor = User.find_by(id: actor_id)
    bytes = File.binread(archive_path)

    Import::JsonArchive::Merge::Orchestrator.new(
      archive_bytes: bytes,
      component: component,
      actor: actor,
      strategy_overrides: strategy_overrides,
      source: source
    ).call
  ensure
    File.unlink(archive_path) if archive_path && File.exist?(archive_path)
  end
end
