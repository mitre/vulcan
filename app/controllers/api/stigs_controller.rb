# frozen_string_literal: true

module Api
  ##
  # Public STIG reference listings for SPA dropdowns.
  # STIGs are published DISA documents — no authentication required.
  #
  class StigsController < BaseController
    include LatestBenchmarkListable

    skip_before_action :authenticate_user!

    latest_listing model: Stig, blueprint: StigBlueprint,
                   columns: %i[id stig_id name title version], order: :title

    # GET /api/stigs/:id/stats — rule count and severity breakdown.
    # Pure reference data (no usage lookup — components are based on SRGs),
    # public like the rest of the STIG catalog.
    def stats
      render json: Stig.find(params[:id]).benchmark_stats
    end
  end
end
