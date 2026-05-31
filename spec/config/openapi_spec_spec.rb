# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require 'json_schemer'

RSpec.describe 'OpenAPI specification (doc/openapi.yaml)' do
  let(:spec_path) { Rails.root.join('doc/openapi.yaml').to_s }
  let(:definition) { OpenapiFirst.load(spec_path) }
  let(:document) { YAML.load_file(spec_path) }

  describe 'spec file' do
    it 'exists and is valid YAML' do
      expect(File.exist?(spec_path)).to be(true)
      expect(document).to be_a(Hash)
    end

    it 'declares OpenAPI 3.2.0' do
      expect(document['openapi']).to eq('3.2.0')
    end

    it 'has correct title and version' do
      expect(document.dig('info', 'title')).to eq('Vulcan API')
      expect(document.dig('info', 'version')).to be_a(String)
    end
  end

  describe 'openapi_first parsing' do
    it 'loads without error' do
      expect { definition }.not_to raise_error
    end

    it 'finds all documented paths' do
      expect(definition.paths.size).to be >= 50
    end
  end

  describe 'json_schemer validation' do
    let(:schemer) { JSONSchemer.openapi(document) }

    it 'accepts the document as valid OpenAPI 3.2' do
      errors = schemer.validate.to_a
      schema_errors = errors.reject { |e| e['data_pointer'].start_with?('/paths') }
      expect(schema_errors).to be_empty,
                               "OpenAPI document has schema errors:\n#{schema_errors.map { |e| "#{e['data_pointer']}: #{e['type']}" }.join("\n")}"
    end
  end

  describe 'contract testing integration' do
    it 'openapi_first test mode is configured with vulcan API' do
      expect(OpenapiFirst::Test.definitions).to have_key(:vulcan)
    end

    context 'contract validation on a real endpoint', type: :request do
      include Devise::Test::IntegrationHelpers

      let!(:admin) { create(:user, admin: true) }

      before { Rails.application.reload_routes! }

      it 'GET /api/version response validates against the spec' do
        sign_in admin
        get '/api/version', headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:ok)

        vulcan_api = OpenapiFirst::Test.definitions[:vulcan]
        validated = vulcan_api.validate_response(request, response, raise_error: false)
        expect(validated).to be_valid,
                             "Response did not match spec: #{validated.error&.message}"
      end
    end
  end

  describe 'response schema completeness' do
    let(:export_paths) { %w[/export/ /bulk_export/] }

    it 'every non-export JSON operation has a response schema with content' do
      missing = []
      document['paths'].each do |path, methods|
        next if export_paths.any? { |ep| path.include?(ep) }

        methods.each do |method, op|
          next if %w[parameters summary description].include?(method)

          responses = op['responses'] || {}
          ok_response = responses['200'] || responses['201'] || {}
          next if ok_response.dig('content', 'application/json', 'schema')
          next if ok_response['$ref']

          missing << "#{method.upcase} #{path}"
        end
      end
      expect(missing).to be_empty,
                         "Operations missing response schema:\n#{missing.join("\n")}"
    end
  end

  describe 'route coverage' do
    before { Rails.application.reload_routes! }

    let(:documented_routes) do
      routes = []
      document['paths'].each do |path, methods|
        methods.each_key do |method|
          next if %w[parameters summary description].include?(method)

          routes << { method: method.upcase, path: path }
        end
      end
      routes
    end

    it 'every documented path is a valid Rails route' do
      missing = []
      documented_routes.each do |route|
        rails_path = route[:path].gsub(/\{(\w+)\}/, '99')
        begin
          Rails.application.routes.recognize_path(rails_path, method: route[:method])
        rescue ActionController::RoutingError
          missing << "#{route[:method]} #{route[:path]}"
        end
      end
      expect(missing).to be_empty,
                         "Documented routes not found in Rails:\n#{missing.join("\n")}"
    end
  end
end
