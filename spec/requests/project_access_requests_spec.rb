# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ProjectAccessRequests' do
  before do
    Rails.application.reload_routes!
    sign_in user
  end

  let(:project) { create(:project) }
  let(:user) { create(:user) }

  describe 'POST /projects/:project_id/project_access_requests' do
    it 'creates a new ProjectAccessRequest' do
      expect do
        post "/projects/#{project.id}/project_access_requests"
      end.to change(ProjectAccessRequest, :count).by(1)

      expect(response).to redirect_to(root_path)
    end

    it 'associates the request with the correct user and project' do
      post "/projects/#{project.id}/project_access_requests"

      access_request = ProjectAccessRequest.last
      expect(access_request.user).to eq(user)
      expect(access_request.project).to eq(project)
    end
  end

  describe 'DELETE /projects/:project_id/project_access_requests/:id' do
    let!(:access_request) { create(:project_access_request, user: user, project: project) }

    it 'destroys the requested ProjectAccessRequest' do
      expect do
        delete "/projects/#{project.id}/project_access_requests/#{access_request.id}"
      end.to change(ProjectAccessRequest, :count).by(-1)

      expect(response).to redirect_to(root_path)
    end

    it 'only allows user to delete their own access request' do
      other_user = create(:user)
      other_request = create(:project_access_request, user: other_user, project: project)

      expect do
        delete "/projects/#{project.id}/project_access_requests/#{other_request.id}"
      end.not_to change(ProjectAccessRequest, :count)
    end
  end
end
