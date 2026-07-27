# frozen_string_literal: true

module Export
  module Modes
    # PublishedSrg mode: the SRG-kind publication filter. Only Applicable
    # authored requirements publish — Not Applicable rows stay on the
    # component as the working record, Not Yet Determined rows never
    # reach a release, and tombstones are excluded (default scope plus
    # the explicit guard here). Serves the XCCDF formatter only.
    #
    # SRG-kind only by construction: the export routing selects this mode
    # from the component's document kind, and the Rule-path association
    # hook stays unimplemented so a misrouted STIG component fails loudly
    # instead of exporting an empty benchmark.
    class PublishedSrg < BaseMode
      # Component-based formatter (XCCDF) builds its own structure.
      def columns
        []
      end

      def headers
        []
      end

      # Terminal filtering: Applicable only, live rows only.
      def rule_scope(rules)
        rules.where(deleted_at: nil, status: 'Applicable')
      end

      def transform_value(_column_key, value, _exportable_rule)
        value
      end

      def supports_srg_kind?
        true
      end

      # Lean XCCDF set — no reviews, no Rule-only associations.
      def srg_eager_load_associations
        %i[disa_rule_descriptions rule_descriptions checks references derived_from]
      end
    end
  end
end
