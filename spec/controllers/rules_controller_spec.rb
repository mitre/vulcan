# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RulesController, type: :controller do
  before(:each) do
    User.destroy_all
    Rule.destroy_all
    @admin_user = FactoryBot.create(:admin_user)
    @user = FactoryBot.create(:user)
  end

  describe 'searching for rules' do
    it 'should return rules that match the query' do
      rule = FactoryBot.create(:rule)
      rule.version = 'SRG-OS-000001-GPOS-00001'
      rule.save!
      sign_in @admin_user
      get :search, params: { q: rule.version }
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)['rules'].map(&:first)).to eq [rule.id]
    end

    it 'should ensure the user is logged in' do
      get :search, params: { q: {} }
      expect(response).to have_http_status(:found)
    end
  end
end
