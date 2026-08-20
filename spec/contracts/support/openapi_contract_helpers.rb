# frozen_string_literal: true

require 'openapi_first'

module OpenAPIContractHelpers
  extend ActiveSupport::Concern

  included do
    let(:vulcan_api) { OpenapiFirst::Test.definitions[:vulcan] }
    let(:json_headers) { { 'Accept' => 'application/json' } }
  end

  def validate_response!(req, resp)
    validated = vulcan_api.validate_response(req, resp, raise_error: false)
    return if validated.valid?

    raise "Contract violation on #{req.method} #{req.path} (#{resp.status}):\n#{validated.error.message}"
  end

  def validate_and_parse!(expected_status: :ok)
    expect(response).to have_http_status(expected_status)
    validate_response!(request, response)
    response.parsed_body
  end

  def assert_fields_present(body, *fields)
    fields.flatten.each do |field|
      expect(body).to have_key(field.to_s),
                      "Expected field '#{field}' in response body but it was absent.\nKeys present: #{body.keys.sort.join(', ')}"
    end
  end

  def assert_fields_absent(body, *fields)
    fields.flatten.each do |field|
      expect(body).not_to have_key(field.to_s),
                          "Field '#{field}' should NOT be in response body (security/privacy).\nKeys present: #{body.keys.sort.join(', ')}"
    end
  end

  def assert_nested_fields(body, path, *fields)
    nested = body.dig(*Array(path).map(&:to_s))
    expect(nested).not_to be_nil,
                          "Expected nested object at path #{Array(path).join('.')} but it was nil"
    fields.flatten.each do |field|
      expect(nested).to have_key(field.to_s),
                        "Expected field '#{field}' in nested object at #{Array(path).join('.')}.\nKeys present: #{nested.keys.sort.join(', ')}"
    end
  end
end
