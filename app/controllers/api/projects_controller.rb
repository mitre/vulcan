# frozen_string_literal: true

module Api
  # Paginated, filterable project listing for SPA consumption.
  class ProjectsController < BaseController
    include ApiFilterable

    before_action :set_project, only: %i[stats triage_summary]
    before_action :authorize_viewer_project, only: %i[stats triage_summary]

    has_scope :search, as: :q

    def index
      # Scoped to what the caller may see (member projects + discoverable), so
      # non-discoverable projects and their admin contacts are not disclosed to
      # non-members. Matches the HTML ProjectsController#index.
      scope = apply_scopes(current_user.available_projects)
      scope = apply_sort(scope, allowed: %w[name created_at updated_at])
      pagy_obj, records = paginate(scope)
      render json: pagy_response(pagy_obj, ProjectBlueprint.render_as_json(records))
    end

    # GET /api/projects/:id/stats — aggregate rule stats across all
    # components plus a per-component breakdown.
    def stats
      render json: @project.dashboard_stats
    end

    # GET /api/projects/:id/triage_summary — triage metrics aggregated
    # across all of the project's components.
    def triage_summary
      render json: Review.triage_summary(@project.components.ids)
    end

    private

    def set_project
      @project = Project.find(params.expect(:id))
    end
  end
end
