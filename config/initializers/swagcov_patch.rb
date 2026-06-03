# frozen_string_literal: true

# Monkey-patch swagcov to handle Rails optional route segments like (/:checks).
# The gem builds a Regexp from the route path but doesn't escape parentheses,
# causing RegexpError on routes with optional segments.
# Filed upstream: https://github.com/smridge/swagcov — pending fix.
if defined?(Swagcov::OpenapiFiles)
  module Swagcov
    # :nodoc:
    class OpenapiFiles
      def find_response_keys(path:, route_verb:)
        escaped_path = path.gsub('(', '\\(').gsub(')', '\\)')
        regex = ::Regexp.new("^#{escaped_path.gsub(%r{:[^/]+}, '\\{[^/]+\\}')}?$")

        matching_paths_key = @openapi_path_keys.grep(regex).first
        matching_request_method_key = @openapi_paths.dig(matching_paths_key, route_verb.downcase)

        matching_request_method_key['responses'].keys.map(&:to_s).sort if matching_request_method_key
      end
    end
  end
end
