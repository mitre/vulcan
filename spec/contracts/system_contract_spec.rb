# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

RSpec.describe 'System + Access Request endpoint contracts', type: :request do
  include Devise::Test::IntegrationHelpers
  include OpenAPIContractHelpers

  before do
    Rails.application.reload_routes!
  end

  # ── POST /consent/acknowledge ──

  describe 'POST /consent/acknowledge' do
    it 'returns 200 OK (no body)' do
      post '/consent/acknowledge', headers: json_headers
      expect(response).to have_http_status(:ok)
      validate_response!(request, response)
    end
  end

  # ── DELETE /projects/:id/project_access_requests/:id ──

  describe 'DELETE /projects/:id/project_access_requests/:id (JSON)' do
    let_it_be(:admin) { create(:user, admin: true) }
    let_it_be(:requester) { create(:user) }
    let_it_be(:project) { create(:project, name: 'Access Request Contract Project') }
    let_it_be(:membership) do
      Membership.find_or_create_by!(user: admin, membership: project, membership_type: 'Project') do |m|
        m.role = 'admin'
      end
    end

    before { sign_in admin }

    it 'returns AccessRequestDestroyResponse with toast + id' do
      access_request = ProjectAccessRequest.create!(user: requester, project: project)

      delete "/projects/#{project.id}/project_access_requests/#{access_request.id}",
             headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast, :id
      expect(body['id']).to eq(access_request.id)
      expect(body.dig('toast', 'variant')).to eq('success')
    end
  end
end
