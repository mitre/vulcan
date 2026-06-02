# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TriageResponseTemplates' do
  include Devise::Test::IntegrationHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:admin)   { create(:user) }
  let_it_be(:viewer)  { create(:user) }
  let_it_be(:outsider) { create(:user) }

  before_all do
    Membership.find_or_create_by!(user: admin,  membership: project) { |m| m.role = 'admin' }
    Membership.find_or_create_by!(user: viewer, membership: project) { |m| m.role = 'viewer' }
  end

  let!(:template) do
    TriageResponseTemplate.create!(project: project, created_by: admin,
                                   name: 'Generalize text',
                                   body: "We'll generalize the check and fix text.")
  end

  describe 'GET /projects/:project_id/triage_response_templates' do
    it 'returns templates for a project member' do
      sign_in viewer
      get "/projects/#{project.id}/triage_response_templates", as: :json
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['triage_response_templates'].first['name']).to eq('Generalize text')
    end

    it 'forbids non-members' do
      sign_in outsider
      get "/projects/#{project.id}/triage_response_templates", as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /projects/:project_id/triage_response_templates' do
    let(:params) do
      { triage_response_template: { name: 'No change required', body: 'We acknowledge — no change required.' } }
    end

    it 'lets a project admin create a template' do
      sign_in admin
      post "/projects/#{project.id}/triage_response_templates", params: params, as: :json
      expect(response).to have_http_status(:created)
      expect(TriageResponseTemplate.find_by(name: 'No change required')).to be_present
    end

    it 'forbids non-admin project members' do
      sign_in viewer
      post "/projects/#{project.id}/triage_response_templates", params: params, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects a duplicate name within the same project' do
      sign_in admin
      post "/projects/#{project.id}/triage_response_templates",
           params: { triage_response_template: { name: 'Generalize TEXT', body: 'collision' } }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH /projects/:project_id/triage_response_templates/:id' do
    it 'lets a project admin update a template' do
      sign_in admin
      patch "/projects/#{project.id}/triage_response_templates/#{template.id}",
            params: { triage_response_template: { body: 'updated body' } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(template.reload.body).to eq('updated body')
    end

    it 'forbids non-admins' do
      sign_in viewer
      patch "/projects/#{project.id}/triage_response_templates/#{template.id}",
            params: { triage_response_template: { body: 'nope' } }, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'DELETE /projects/:project_id/triage_response_templates/:id' do
    it 'lets a project admin delete a template' do
      sign_in admin
      delete "/projects/#{project.id}/triage_response_templates/#{template.id}", as: :json
      expect(response).to have_http_status(:no_content)
      expect(TriageResponseTemplate.find_by(id: template.id)).to be_nil
    end

    it 'forbids non-admins' do
      sign_in viewer
      delete "/projects/#{project.id}/triage_response_templates/#{template.id}", as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
