# frozen_string_literal: true

module Api
  ##
  # Released-component reference listings for SPA dropdowns. A component is
  # a STIG in progress — released ones are instance-wide reference data for
  # any authenticated user (same visibility as the components list page).
  #
  class ComponentsController < BaseController
    include LatestBenchmarkListable

    before_action :set_component, only: %i[summary stats workflow_state triage_summary]
    before_action :authorize_component_access, only: %i[summary stats workflow_state triage_summary]

    latest_listing model: Component, blueprint: ComponentBlueprint,
                   columns: %i[id prefix name title version release], order: :prefix

    # GET /api/components/:id/summary — lightweight header for SPA
    # triage/settings routes: identity, counts, srg info,
    # effective_permissions, and the serialized comment-phase state
    # machine. Never ships rules/reviews/histories. Access matches
    # components#show: released → any authenticated user, else viewer.
    def summary
      render json: ComponentBlueprint.render_as_json(
        @component,
        view: :summary,
        current_user: current_user,
        pending_comment_counts: Component.pending_comment_counts([@component.id])
      )
    end

    # GET /api/components/:id/stats — rule counts by status/severity plus
    # completion and lock percentages, as SQL aggregates.
    def stats
      render json: @component.dashboard_stats
    end

    # GET /api/components/:id/workflow_state — readiness across the
    # authoring -> lock -> review -> comment -> triage -> export flow.
    def workflow_state
      render json: @component.workflow_state
    end

    # GET /api/components/:id/triage_summary — top-level comment counts per
    # triage status + adjudication percentage.
    def triage_summary
      render json: Review.triage_summary([@component.id])
    end

    private

    def set_component
      @component = Component.find(params[:id])
    end

    # Components are not public DISA documents — only released ones are
    # visible, and only to authenticated users.
    def latest_base_scope
      Component.where(released: true)
    end
  end
end
