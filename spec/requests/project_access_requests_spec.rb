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
    context 'with HTML format' do
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

    context 'with JSON format' do
      it 'creates a new ProjectAccessRequest and returns JSON' do
        expect do
          post "/projects/#{project.id}/project_access_requests", headers: { 'Accept' => 'application/json' }
        end.to change(ProjectAccessRequest, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(response.content_type).to match(%r{application/json})

        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Your request for access has been sent.')
      end

      it 'returns error for duplicate request' do
        create(:project_access_request, user: user, project: project)

        post "/projects/#{project.id}/project_access_requests", headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to match(%r{application/json})

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('already requested access')
      end
    end
  end

  describe 'DELETE /projects/:project_id/project_access_requests/:id' do
    let!(:access_request) { create(:project_access_request, user: user, project: project) }

    context 'with HTML format' do
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

    context 'with JSON format' do
      it 'destroys the requested ProjectAccessRequest and returns JSON' do
        expect do
          delete "/projects/#{project.id}/project_access_requests/#{access_request.id}",
                 headers: { 'Accept' => 'application/json' }
        end.to change(ProjectAccessRequest, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(%r{application/json})

        json_response = JSON.parse(response.body)
        expect(json_response['message']).to include('cancelled')
      end

      it 'returns forbidden when trying to delete another users request' do
        other_user = create(:user)
        other_request = create(:project_access_request, user: other_user, project: project)

        expect do
          delete "/projects/#{project.id}/project_access_requests/#{other_request.id}",
                 headers: { 'Accept' => 'application/json' }
        end.not_to change(ProjectAccessRequest, :count)

        expect(response).to have_http_status(:forbidden)
        expect(response.content_type).to match(%r{application/json})

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('not authorized')
      end
    end
  end
end
