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

  # Coverage off by default — parallel workers only see a subset of routes,
  # producing misleading per-worker numbers. Enable with OPENAPI_COVERAGE=1
  # for single-process runs (rake openapi:coverage).
  if ENV['OPENAPI_COVERAGE'] == '1'
    test.report_coverage = :warn
    test.coverage_reporter = OpenapiFirst::Test::Coverage::TerminalReporter
    test.coverage_reporter_options = { verbose: false }
  else
    test.report_coverage = false
  end
end

# Auto-validate every JSON request spec response against the OpenAPI schema.
# Skips: HTML responses, redirect responses, opt-outs via `openapi: false`.
# Undocumented endpoints are silently skipped (ignore_response_error above).
RSpec.configure do |config|
  config.after(:each, type: :request) do |example|
    next if example.metadata[:openapi] == false
    next unless response&.status
    next if response.redirect?
    next unless response.content_type&.include?('application/json')

    api = OpenapiFirst::Test[:vulcan]
    validated = api.validate_response(request, response, raise_error: false)
    next unless validated
    next if validated.unknown?

    raise validated.error.exception if validated.invalid?
  end
end
