# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProjectsController, type: :controller do
  before(:each) do
    User.destroy_all
    Project.destroy_all
    @admin_user = FactoryBot.create(:admin_user)
    @user = FactoryBot.create(:user)
    5.times.each { FactoryBot.create(:project) }
  end

  describe 'viewing projects' do
    it 'should return a list of all projects for admin users' do
      sign_in @admin_user
      get :index, format: :json

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).map { |p| p['id'] }).to eq Project.all.alphabetical.pluck(:id)
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
    it 'should return projects that match the query' do
      component = FactoryBot.create(:component)
      sign_in @admin_user
      get :search, params: { q: component.based_on.srg_id }
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)['projects'].map(&:first)).to eq Component.all.pluck(:project_id)
    end

    it 'should ensure the user is logged in' do
      get :search, params: { q: {} }
      expect(response).to have_http_status(:found)
    end
  end

  describe 'creating a project' do
    before(:each) do
      @project_count = Project.all.size
    end

    it 'should not create project if user is not signed in' do
      post :create

      expect(response).to have_http_status(:found)
      expect(Project.all.size).to eq @project_count
    end

    it 'should successfully create project if signed in as admin user' do
      sign_in @user
      post :create, params: { project: { name: 'project 1' } }

      expect(response).to have_http_status(:found)
      expect(Project.all.size).to eq @project_count + 1
    end

    it 'should successfully create project if signed in as non-admin user' do
      sign_in @user
      post :create, params: { project: { name: 'project 1' } }

      expect(response).to have_http_status(:found)
      expect(Project.all.size).to eq @project_count + 1
    end
  end

  describe 'updating a project' do
    before(:each) do
      @project = FactoryBot.create(:project)
    end

    it 'should only allow admin users to update a project' do
      sign_in @user
      put :update, params: { id: @project.id, project: { name: 'project 2' } }

      expect(response).to have_http_status(:found)
    end

    it 'should update project if user is admin' do
      sign_in @admin_user
      put :update, params: { id: @project.id, project: { name: 'project 2' } }

      expect(response).to have_http_status(:success)
      expect(Project.find_by(id: @project.id).name).to eq('project 2')
    end
  end

  describe 'deleting a project' do
    before(:each) do
      @project = FactoryBot.create(:project)
    end

    it 'should only allow admin users to delete a project' do
      sign_in @user
      delete :destroy, params: { id: @project.id }

      expect(response).to have_http_status(:found)
    end

    it 'should delete project if user is admin' do
      sign_in @admin_user
      delete :destroy, params: { id: @project.id }

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
  end
end
