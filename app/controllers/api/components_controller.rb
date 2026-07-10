# frozen_string_literal: true

module Api
  ##
  # Released-component reference listings for SPA dropdowns. A component is
  # a STIG in progress — released ones are instance-wide reference data for
  # any authenticated user (same visibility as the components list page).
  #
  class ComponentsController < BaseController
    include LatestBenchmarkListable

    latest_listing model: Component, blueprint: ComponentBlueprint,
                   columns: %i[id prefix name title version release], order: :prefix

    private

    # Components are not public DISA documents — only released ones are
    # visible, and only to authenticated users.
    def latest_base_scope
      Component.where(released: true)
    end
  end
end
