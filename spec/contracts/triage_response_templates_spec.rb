# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

RSpec.describe 'Triage Response Templates API', type: :request do
  include Devise::Test::IntegrationHelpers
  include OpenAPIContractHelpers

  let!(:admin) { create(:user, admin: true) }
  let!(:project) { create(:project) }
  let!(:membership) { create(:membership, user: admin, membership: project, role: 'admin') }
  let(:json_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  before do
    Rails.application.reload_routes!
    sign_in admin
  end

  describe 'GET /projects/:project_id/triage_response_templates' do
    let!(:template) do
      TriageResponseTemplate.create!(
        project: project,
        created_by: admin,
        name: 'Accept standard',
        body: 'Concur with the finding as written.'
      )
    end

    it 'returns templates array matching schema' do
      get "/projects/#{project.id}/triage_response_templates", headers: json_headers

      expect(response).to have_http_status(:ok)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body['triage_response_templates'].length).to eq(1)
      expect(body['triage_response_templates'][0]['name']).to eq('Accept standard')
      expect(body['triage_response_templates'][0]['id']).to eq(template.id)
    end
  end

  describe 'POST /projects/:project_id/triage_response_templates' do
    it 'creates a template and matches schema' do
      post "/projects/#{project.id}/triage_response_templates",
           params: { triage_response_template: { name: 'Decline', body: 'Not applicable.' } }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:created)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body['triage_response_template']['name']).to eq('Decline')
      expect(body['triage_response_template']['body']).to eq('Not applicable.')
      expect(body['triage_response_template']['created_by_id']).to eq(admin.id)
    end
  end

  describe 'PATCH /projects/:project_id/triage_response_templates/:id' do
    let!(:template) do
      TriageResponseTemplate.create!(
        project: project,
        created_by: admin,
        name: 'Original',
        body: 'Original body'
      )
    end

    it 'updates a template and matches schema' do
      patch "/projects/#{project.id}/triage_response_templates/#{template.id}",
            params: { triage_response_template: { name: 'Updated', body: 'Updated body' } }.to_json,
            headers: json_headers

      expect(response).to have_http_status(:ok)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body['triage_response_template']['name']).to eq('Updated')
    end
  end

  describe 'DELETE /projects/:project_id/triage_response_templates/:id' do
    let!(:template) do
      TriageResponseTemplate.create!(
        project: project,
        created_by: admin,
        name: 'To delete',
        body: 'Will be removed'
      )
    end

    it 'deletes and returns 204' do
      delete "/projects/#{project.id}/triage_response_templates/#{template.id}",
             headers: json_headers

      expect(response).to have_http_status(:no_content)
      expect(TriageResponseTemplate.find_by(id: template.id)).to be_nil
    end
  end
end
