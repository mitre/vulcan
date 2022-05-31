# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProjectsController, type: :controller do
  User.destroy_all
  admin_user = FactoryBot.create(:admin_user)
  user = FactoryBot.create(:user)
  5.times.each { FactoryBot.create(:project) }

  describe 'viewing projects' do
    it 'should return a list of all projects for admin users' do
      sign_in admin_user
      get :index, format: :json

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).map { |p| p['id'] }).to eq Project.all.alphabetical.pluck(:id)
    end

    it 'should return a list of available projects for users' do
      Project.all.limit(3).each do |project|
        user.memberships << Membership.new(membership_type: 'Project', membership_id: project.id, role: 'viewer')
      end
      sign_in user
      get :index, format: :json
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).map { |p| p['id'] }).to eq user.available_projects.alphabetical.pluck(:id)
    end
  end
end
