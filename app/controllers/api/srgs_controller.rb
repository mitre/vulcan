# frozen_string_literal: true

module Api
  ##
  # Public SRG reference listings for SPA dropdowns.
  # SRGs are published DISA documents — no authentication required.
  #
  class SrgsController < BaseController
    include LatestBenchmarkListable

    # Only the latest listing is public — stats exposes component usage
    # (project-scoped data) and requires authentication.
    skip_before_action :authenticate_user!, only: :latest

    latest_listing model: SecurityRequirementsGuide, blueprint: SrgBlueprint,
                   columns: %i[id srg_id name title version], order: :title

    # Lexically anchors the concern-provided action so the scoped
    # skip_before_action above is verifiable (Rails/LexicallyScopedActionFilter).
    def latest
      super
    end

    # GET /api/srgs/:id/stats — rule count, severity breakdown, and which
    # components are based on this SRG. Usage is scoped to components the
    # caller can see (member projects or released) — count and list use the
    # SAME scope so the count never leaks hidden usage.
    def stats
      srg = SecurityRequirementsGuide.find(params.expect(:id))
      render json: srg.benchmark_stats.merge(usage: usage_payload(srg))
    end

    private

    def usage_payload(srg)
      based_on = Component.where(security_requirements_guide_id: srg.id)
      visible = based_on.where(project_id: current_user.available_projects.select(:id))
                        .or(based_on.where(released: true))
      rows = visible.joins(:project)
                    .order('components.prefix')
                    .pluck('components.id', 'components.name', 'components.project_id', 'projects.name')
      {
        count: rows.size,
        components: rows.map do |id, name, project_id, project_name|
          { id: id, name: name, project_id: project_id, project_name: project_name }
        end
      }
    end
  end
end
