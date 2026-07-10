# frozen_string_literal: true

require 'rails_helper'

# JSON responses for the project access request lifecycle. The create action
# must return the canonical toast shape (plus the new request id) so API
# clients can request access and surface validation errors — the HTML
# flash+redirect flow is covered in project_access_requests_spec.rb.
RSpec.describe 'ProjectAccessRequests JSON' do
  # Create admin first to prevent first-user-admin callback from promoting test users
  # NOTE: let! must be defined BEFORE the before block so its implicit before hook
  # runs first, ensuring existing_admin is created before user
  let!(:existing_admin) { create(:user, admin: true) } # -- side effect: prevents first-user-admin promotion
  let(:project) { create(:project) }
  let(:user) { create(:user) }

  before do
    Rails.application.reload_routes!
    sign_in user
  end

  describe 'POST /projects/:project_id/project_access_requests (JSON)' do
    it 'creates the request and returns a success toast with the new request id' do
      expect do
        post "/projects/#{project.id}/project_access_requests", as: :json
      end.to change(ProjectAccessRequest, :count).by(1)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig('toast', 'title')).to eq('Access request submitted.')
      expect(body.dig('toast', 'message')).to eq(['Your request for access has been sent.'])
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body['id']).to eq(ProjectAccessRequest.find_by!(user: user, project: project).id)
    end

    it 'returns a 422 danger toast when the user already requested access' do
      create(:project_access_request, user: user, project: project)

      expect do
        post "/projects/#{project.id}/project_access_requests", as: :json
      end.not_to change(ProjectAccessRequest, :count)

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body.dig('toast', 'title')).to eq('Could not request access.')
      expect(body.dig('toast', 'message')).to eq(['User has already requested access to this project'])
      expect(body.dig('toast', 'variant')).to eq('danger')
    end
  end

  describe 'DELETE /projects/:project_id/project_access_requests/:id (JSON)' do
    it 'returns a cancelled toast when the requester cancels their own request' do
      access_request = create(:project_access_request, user: user, project: project)

      delete "/projects/#{project.id}/project_access_requests/#{access_request.id}", as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig('toast', 'title')).to eq('Access request cancelled.')
      expect(body.dig('toast', 'message')).to eq(["Your request to access #{project.name} has been cancelled."])
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body['id']).to eq(access_request.id)
    end

    it 'returns a denied toast when a project admin denies a request' do
      project_admin = create(:user)
      create(:membership, :admin, user: project_admin, membership: project)
      requester = create(:user)
      access_request = create(:project_access_request, user: requester, project: project)
      sign_in project_admin

      delete "/projects/#{project.id}/project_access_requests/#{access_request.id}", as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig('toast', 'title')).to eq('Access request denied.')
      expect(body.dig('toast', 'message')).to eq(["Successfully denied #{requester.name}'s request to access project."])
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body['id']).to eq(access_request.id)
    end
  end
end
