# frozen_string_literal: true

# Phase 2c controller for component sync/merge.
#
# POST /components/:id/merge        — accepts a backup zip upload, enqueues
#                                     MergeJob, returns { job_id, status }
# GET  /components/:id/merge_status — latest ComponentSyncEvent status +
#                                     summary + failure_diagnostics
#
# Merge resolution (POST /components/:id/merge_resolve) is intentionally
# deferred to a follow-up — it depends on UI surfacing the conflict set.
class SyncController < ApplicationController
  include UploadValidatable

  UPLOAD_DIR = Rails.root.join('storage/merge_uploads').freeze

  before_action :set_component, only: %i[create status]
  before_action :authorize_admin_component, only: %i[create]
  before_action :authorize_viewer_component, only: %i[status]
  before_action -> { validate_upload(:file, max_size: 100.megabytes, allowed_types: %w[.zip]) },
                only: :create

  def create
    file = params[:file]
    return render_no_file unless file

    overrides = parse_strategy_overrides
    return render_invalid_overrides if overrides == :invalid

    path = persist_upload(file)

    job = MergeJob.perform_later(
      component_id: @component.id,
      archive_path: path,
      actor_id: current_user.id,
      strategy_overrides: overrides
    )

    render json: {
      job_id: job.job_id,
      component_id: @component.id,
      status: 'queued',
      message: 'Merge enqueued. Poll GET /components/:id/merge_status for progress.'
    }
  end

  def status
    event = ComponentSyncEvent.where(component: @component).order(created_at: :desc).first
    return render json: { status: 'no_sync_yet' }, status: :not_found if event.nil?

    render json: {
      sync_event_id: event.id,
      sync_id: event.sync_id,
      status: event.status,
      source: event.source,
      direction: event.direction,
      created_at: event.created_at,
      archive_hash: event.archive_hash,
      snapshot_path: event.snapshot_path,
      failure_diagnostics: event.failure_diagnostics_json
    }
  end

  private

  def set_component
    @component = Component.find_by(id: params[:id])
    return if @component

    render json: { error: 'Component not found.' }, status: :not_found
  end

  def authorize_viewer_component
    @project = @component.project
    return if current_user&.can_view_project?(@project)

    raise NotAuthorizedError, 'You are not authorized to view this component'
  end

  def authorize_admin_component
    @project = @component.project
    return if current_user&.can_admin_component?(@component)

    raise NotAuthorizedError, 'You are not authorized to perform administrator actions on this component'
  end

  # Persist the upload to a known location with restrictive perms. MergeJob
  # is responsible for unlinking after the read.
  def persist_upload(file)
    FileUtils.mkdir_p(UPLOAD_DIR, mode: 0o700) unless UPLOAD_DIR.exist?
    File.chmod(0o700, UPLOAD_DIR)
    path = UPLOAD_DIR.join("#{SecureRandom.hex(12)}.zip").to_s
    File.binwrite(path, file.read)
    File.chmod(0o600, path)
    path
  end

  def parse_strategy_overrides
    raw = params[:strategy_overrides]
    return nil if raw.blank?

    parsed = raw.is_a?(String) ? JSON.parse(raw) : raw
    parsed.is_a?(Hash) ? parsed.deep_symbolize_keys : :invalid
  rescue JSON::ParserError
    :invalid
  end

  def render_no_file
    render json: { error: 'No file provided. Attach a backup zip as the `file` param.' },
           status: :bad_request
  end

  def render_invalid_overrides
    render json: { error: 'strategy_overrides must be a JSON object.' },
           status: :bad_request
  end
end
