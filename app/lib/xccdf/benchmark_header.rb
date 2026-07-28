# frozen_string_literal: true

module Xccdf
  # Light benchmark-header reader — the identity fields of an XCCDF
  # document without the full mapping parse. SAX-based and terminating at
  # the first Profile or Group, so the cost stays flat regardless of how
  # many rules the document carries.
  class BenchmarkHeader
    Fields = Struct.new(:benchmark_id, :title, :version, :release_info, keyword_init: true)

    # Raised internally to stop the SAX walk once the header is behind us.
    class HeaderComplete < StandardError; end

    # SAX callbacks: collects the benchmark id attribute, the first
    # benchmark-level title, the version element, and the release-info
    # plain-text, then stops the walk at the first Profile or Group.
    class Handler < Ox::Sax
      attr_reader :fields

      def initialize
        super
        @fields = Fields.new
        @depth = 0
        @element = nil
        @plain_text_id = nil
      end

      def start_element(name)
        raise HeaderComplete if @depth == 1 && %i[Profile Group].include?(name)

        @depth += 1
        @element = name
        @plain_text_id = nil if name == :'plain-text'
      end

      def end_element(_name)
        @depth -= 1
        @element = nil
      end

      def attr(name, value)
        @fields.benchmark_id ||= value if @element == :Benchmark && name == :id
        @plain_text_id = value if @element == :'plain-text' && name == :id
      end

      def text(value)
        return unless @depth == 2

        case @element
        when :title then @fields.title ||= value
        when :version then @fields.version ||= value
        when :'plain-text'
          @fields.release_info ||= value if @plain_text_id == 'release-info'
        end
      end
    end

    # Returns Fields with nil members when the document is not parseable —
    # callers surface that through their own presence/consistency checks.
    def self.parse(xml)
      handler = Handler.new
      Ox.sax_parse(handler, StringIO.new(xml.to_s))
      handler.fields
    rescue HeaderComplete
      handler.fields
    rescue Ox::ParseError
      Fields.new
    end
  end
end
