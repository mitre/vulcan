# frozen_string_literal: true

module Export
  module Modes
    # Abstract base for export modes. Modes determine:
    # - Which rules to include (rule_scope)
    # - Which columns to export (columns/headers)
    # - How to transform values per-column (transform_value)
    # - What associations to eager load (eager_load_associations)
    class BaseMode
      def columns
        raise NotImplementedError
      end

      def headers
        raise NotImplementedError
      end

      # Filters/scopes the rule relation. Override to exclude rules by status, etc.
      def rule_scope(rules)
        rules
      end

      # Transform a single value. Override for DISA field-blanking, etc.
      # Returns the (possibly modified) value.
      def transform_value(_column_key, value, _exportable_rule)
        value
      end

      # Associations to eager_load on the rules relation for this mode.
      def eager_load_associations
        raise NotImplementedError
      end
    end
  end
end
