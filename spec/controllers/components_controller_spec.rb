# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ComponentsController, type: :controller do
  before(:each) do
    User.destroy_all
    @admin_user = FactoryBot.create(:admin_user)
  end

  describe 'searching for components' do
    it 'should return components match the query' do
      component = FactoryBot.create(:component)
      sign_in @admin_user
      get :search, params: { q: component.based_on.srg_id }
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)['components'].map(&:first)).to eq Component.all.pluck(:id)
    end

    it 'should ensure the user is loggen in' do
      get :search, params: { q: {} }
      expect(response).to have_http_status(:found)
    end
  end
end
