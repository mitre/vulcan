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

  # Observe all requests through the Rails app so every request spec
  # automatically contributes to API coverage tracking. Validation errors
  # are logged (not raised) — the explicit contract tests in
  # spec/contracts/ are where schema mismatches should hard-fail.
  test.observe(Rails.application, api: :vulcan)
  test.response_raise_error = false

  # Warn on incomplete coverage instead of hard-failing (exit 2).
  # Coverage grows incrementally as contract tests expand.
  test.report_coverage = :warn
end
