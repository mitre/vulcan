# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ComponentsController, type: :controller do
  before(:each) do
    User.destroy_all
    @admin_user = FactoryBot.create(:admin_user)
    @user = FactoryBot.create(:user)
    @project_id = Project.first.id
    @srg_id = SecurityRequirementsGuide.first.id
  end

  describe 'searching for components' do
    it 'should return components that match the query' do
      component = FactoryBot.create(:component)
      sign_in @admin_user
      get :search, params: { q: component.based_on.srg_id }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)['components'].map(&:first)).to eq Component.all.pluck(:id)
    end

    it 'should ensure the user is logged in' do
      get :search, params: { q: {} }

      expect(response).to have_http_status(:found)
    end
  end

  describe 'showing a component' do
    it 'should return component json' do
      component = FactoryBot.create(:component)
      sign_in @admin_user
      get :show, format: :json, params: { id: component.id }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).keys).to include(*%w[histories memberships metadata inherited_memberships
                                                            available_members rules reviews])
    end

    it 'should return component json' do
      component = FactoryBot.create(:component)
      sign_in @user
      get :show, format: :json, params: { id: component.id }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).keys).to include(*%w[rules reviews])
      expect(JSON.parse(response.body).keys).not_to include(*%w[histories memberships metadata inherited_memberships
                                                                available_members])
    end
  end

  describe 'creating a component' do
    it 'should not create component if user is not admin of project' do
      sign_in @user
      post :create, params: { project_id: @project_id, component: { name: 'comp 1', prefix: 'ABCD-00',
                                                                    security_requirements_guide_id: @srg_id } }

      expect(response).to have_http_status(:found)
    end

    it 'should create a component' do
      sign_in @admin_user
      post :create, params: { project_id: @project_id, component: { name: 'comp 1', prefix: 'ABCD-00',
                                                                    security_requirements_guide_id: @srg_id } }

      expect(response).to have_http_status(:success)
    end
  end

  describe 'updating a component' do
    it 'should not update component if user does not have permission' do
      component = FactoryBot.create(:component)
      sign_in @user
      put :update, params: { project_id: @project_id, id: component.id }

      expect(response).to have_http_status(:found)
    end

    it 'should update a component if user has permission' do
      component = FactoryBot.create(:component)
      sign_in @admin_user
      put :update, params: { project_id: @project_id, id: component.id, component: { name: 'comp 2' } }

      expect(response).to have_http_status(:success)
    end
  end

  describe 'deleting a component' do
    it 'should not delete component if user does not have permission' do
      component = FactoryBot.create(:component)
      sign_in @user
      delete :destroy, params: { project_id: @project_id, id: component.id }

      expect(response).to have_http_status(:found)
    end

    it 'should delete component if user has permission' do
      component = FactoryBot.create(:component)
      sign_in @admin_user
      delete :destroy, params: { project_id: @project_id, id: component.id }

      expect(response).to have_http_status(:success)
    end
  end
end
