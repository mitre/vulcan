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
end
