# frozen_string_literal: true

# Shared GET #latest implementation for benchmark reference listings —
# SRGs, STIGs, and released Components share one response contract:
#   { rows: [...] } — one row per document, its numerically highest release,
#   optional ?q= filter via the model's SearchQueryService-backed search.
#
# Controllers declare the shape:
#
#   latest_listing model: Stig, blueprint: StigBlueprint,
#                  columns: %i[id stig_id name title version], order: :title
#
# and may override #latest_base_scope to restrict visibility
# (e.g., released components only). The model must implement
# `latest_versions` (grouped by benchmark id, numerically ranked) and `search`
# (BenchmarkSearchable).
module LatestBenchmarkListable
  extend ActiveSupport::Concern

  included do
    class_attribute :latest_listing_config, instance_writer: false
  end

  class_methods do
    def latest_listing(model:, blueprint:, columns:, order:)
      self.latest_listing_config = { model: model, blueprint: blueprint, columns: columns, order: order }
    end
  end

  def latest
    config = latest_listing_config
    records = latest_base_scope.latest_versions
                               .select(*config[:columns])
                               .order(config[:order])
    records = records.search(params[:q]) if params[:q].present?
    render json: { rows: config[:blueprint].render_as_json(records, view: :latest) }
  end

  private

  # Override to restrict visibility. The default — the whole table — is
  # correct for public DISA reference data (SRGs, STIGs).
  def latest_base_scope
    latest_listing_config[:model].all
  end
end
