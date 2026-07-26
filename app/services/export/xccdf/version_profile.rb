# frozen_string_literal: true

module Export
  module Xccdf
    # The ONE place XCCDF version variance lives: namespace,
    # schemaLocation, and the object-id encoding. The content model stays
    # version-agnostic in the formatter; a new XCCDF version is a new
    # frozen profile row here — never a forked formatter.
    #
    # format_id(type, raw) is the single auditable source of truth for
    # id encoding: 1.1.4 ids pass through untouched; a 1.2 profile wraps
    # the same raw id deterministically (xccdf_{owner}_{type}_{raw}).
    class VersionProfile
      attr_reader :key, :namespace, :schema_location

      def initialize(key:, namespace:, schema_location:, id_formatter:)
        @key = key
        @namespace = namespace
        @schema_location = schema_location
        @id_formatter = id_formatter
        freeze
      end

      def format_id(type, raw)
        @id_formatter.call(type, raw)
      end

      V1_1_4 = new(
        key: '1.1.4',
        namespace: 'http://checklists.nist.gov/xccdf/1.1',
        # schemaLocation is whitespace-separated namespace/location pairs.
        # The pre-profile exporter emitted a malformed string (missing
        # space between the xsd and the cpe namespace) — fixed here.
        schema_location: 'http://checklists.nist.gov/xccdf/1.1 ' \
                         'http://nvd.nist.gov/schema/xccdf-1.1.4.xsd ' \
                         'http://cpe.mitre.org/dictionary/2.0 ' \
                         'http://cpe.mitre.org/files/cpe-dictionary_2.1.xsd',
        id_formatter: ->(_type, raw) { raw }
      )

      private_class_method :new
    end
  end
end
