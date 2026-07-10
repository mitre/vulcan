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
  end
end
