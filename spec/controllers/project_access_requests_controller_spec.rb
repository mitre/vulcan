# frozen_string_literal: true

# spec/controllers/project_access_requests_controller_spec.rb
require 'rails_helper'

RSpec.describe ProjectAccessRequestsController, type: :controller do
  include LoginHelpers

  let(:project) { create(:project) }
  let(:user) { create(:user) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    sign_in user
  end

  describe 'POST #create' do
    it 'creates a new ProjectAccessRequest' do
      expect do
        post :create, params: { project_id: project.id }
      end.to change { ProjectAccessRequest.count }.by(1)
    end

    it 'redirects to the root/projects path' do
      post :create, params: { project_id: project.id }
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'DELETE #destroy' do
    let!(:access_request) { create(:project_access_request, user: user, project: project) }

    it 'destroys the requested ProjectAccessRequest' do
      expect do
        delete :destroy, params: { project_id: project.id, id: access_request.id }
      end.to change { ProjectAccessRequest.count }.by(-1)
    end

    it 'redirects to the fallback location or projects path' do
      delete :destroy, params: { project_id: project.id, id: access_request.id }
      expect(response).to redirect_to(projects_path)
    end
  end
end
