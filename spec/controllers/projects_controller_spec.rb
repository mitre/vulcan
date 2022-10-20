# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProjectsController, type: :controller do
  before(:all) do
    @admin_user = FactoryBot.create(:admin_user)
    @user = FactoryBot.create(:user)
    2.times.each do
      FactoryBot.create(:component)
      FactoryBot.create(:released_component)
    end
  end

  after(:all) do
    User.destroy_all
    Project.destroy_all
    Component.destroy_all
    SecurityRequirementsGuide.destroy_all
  end

  describe 'viewing projects' do
    it 'should ensure the user is logged in' do
      get :index

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'should return a list of all projects for admin users' do
      sign_in @admin_user
      get :index, format: :json

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).map { |p| p['id'] }).to eq Project.alphabetical.pluck(:id)
    end

    it 'should return a list of available projects for users' do
      Project.all.limit(3).each do |project|
        @user.memberships << Membership.new(membership_type: 'Project', membership_id: project.id, role: 'viewer')
      end
      sign_in @user
      get :index, format: :json

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).map { |p| p['id'] }).to eq @user.available_projects.alphabetical.pluck(:id)
    end
  end

  describe 'searching for projects' do
    it 'should ensure the user is logged in' do
      component = Component.first
      get :search, params: { q: component.based_on.srg_id }

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'should return projects that match the query' do
      srg_id = SecurityRequirementsGuide.last.srg_id
      sign_in @admin_user
      get :search, params: { q: srg_id }
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)['projects'].map(&:first)).to eq @admin_user.available_projects
                                                                                  .joins(components: :based_on)
                                                                                  .and(SecurityRequirementsGuide.where(srg_id: srg_id))
                                                                                  .distinct
                                                                                  .pluck(:id)
    end
  end

  describe 'showing a project' do
    it 'should ensure the user is logged in' do
      get :show, params: { id: '' }

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'should not allow users with no permission to view a project' do
      sign_in @user
      get :show, format: :json, params: { id: Project.first.id }

      expect(response).to have_http_status(:internal_server_error)
    end

    it 'should allow users with permission to view a project' do
      sign_in @admin_user
      get :show, format: :json, params: { id: Project.first.id }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).keys).to include(*%w[histories memberships metadata components
                                                            available_components available_members details])
    end
  end

  describe 'creating a project' do
    it 'should not create project if user is not signed in' do
      expect { post :create }.not_to change(Project, :count)
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'should successfully create project if signed in as admin user' do
      sign_in @admin_user

      expect do
        post(:create, params: { project: { name: 'project 1' } })
      end.to change(Project, :count).by(1)
      expect(response).to redirect_to(project_path(Project.last.id))
    end

    it 'should successfully create project if signed in as non-admin user' do
      sign_in @user

      expect do
        post(:create, params: { project: { name: 'project 1' } })
      end.to change(Project, :count).by(1)
      expect(response).to redirect_to(project_path(Project.last.id))
    end
  end

  describe 'updating a project' do
    let(:project) { Project.first }
    it 'should ensure the user is logged in' do
      put :update, params: { id: project.id, project: { name: 'project 2' } }

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'should only allow admin users to update a project' do
      sign_in @user
      put :update, params: { id: project.id, project: { name: 'project 2' } }

      expect(response).to have_http_status(:found)
    end

    it 'should update project if user is admin' do
      sign_in @admin_user
      put :update, params: { id: project.id, project: { name: 'project 2' } }

      expect(response).to have_http_status(:success)
      expect(Project.find_by(id: project.id).name).to eq('project 2')
    end
  end

  describe 'deleting a project' do
    let(:project) { Project.first }

    it 'should ensure a user is logged in' do
      delete :destroy, params: { id: project.id }

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'should only allow admin users to delete a project' do
      sign_in @user
      delete :destroy, params: { id: project.id }

      expect(response).to have_http_status(:found)
    end

    it 'should delete project if user is admin' do
      sign_in @admin_user
      delete :destroy, params: { id: project.id }

      expect(flash[:notice]).to eq 'Successfully removed project.'
    end
  end

  describe 'exporting a project' do
    it 'should only allow all users to export' do
      [@user, @admin_user].each do |u|
        sign_in u
        post :export, params: { id: Project.first.id, type: 'excel' }

        expect(response).to have_http_status(:success)
      end
    end

    it 'should only allow excel, xccdf, and inspec export' do
      sign_in @user
      get :export, format: :json, params: { id: Project.first.id, type: 'csv' }

      expect(response).to have_http_status(:bad_request)
    end
  end
end
