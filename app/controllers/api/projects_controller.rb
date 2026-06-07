# frozen_string_literal: true

module Api
  # Paginated, filterable project listing for SPA consumption.
  class ProjectsController < BaseController
    include ApiFilterable

    has_scope :search, as: :q

    def index
      scope = apply_scopes(Project.all)
      scope = apply_sort(scope, allowed: %w[name created_at updated_at])
      pagy_obj, records = paginate(scope)
      render json: pagy_response(pagy_obj, ProjectBlueprint.render_as_json(records))
    end
  end
end
