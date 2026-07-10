# frozen_string_literal: true

module Api
  ##
  # Public SRG reference listings for SPA dropdowns.
  # SRGs are published DISA documents — no authentication required.
  #
  class SrgsController < BaseController
    include LatestBenchmarkListable

    skip_before_action :authenticate_user!

    latest_listing model: SecurityRequirementsGuide, blueprint: SrgBlueprint,
                   columns: %i[id srg_id name title version], order: :title
  end
end
