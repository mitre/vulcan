# frozen_string_literal: true

require 'openapi_first'
require 'openapi_first/test'

OpenapiFirst::Test.setup do |test|
  test.register(Rails.root.join('doc/openapi.yaml').to_s, as: :vulcan)

  test.ignore_request_error(&:unknown?)

  test.ignore_response_error do |validated_response, _rack_request|
    validated_response.unknown?
  end

  test.ignore_unknown_response_status = true

  # Disable coverage reporting — each parallel worker only sees a subset
  # of routes, producing misleading per-worker coverage numbers and
  # non-zero exit codes that make parallel_tests report "Tests Failed"
  # even with 0 rspec failures. Run contract tests standalone for coverage.
  test.report_coverage = false
end
