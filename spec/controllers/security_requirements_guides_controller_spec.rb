# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SecurityRequirementsGuidesController, type: :controller do
  before(:each) do
    @request.env['devise.mapping'] = Devise.mappings[:user]
  end

  describe 'viewing SRGs' do
    context 'when user is admin' do
      it 'should be allowed' do
        sign_in FactoryBot.create(:admin_user)
        get :index
        assert_response :success
      end
    end

    context 'when user is not an admin' do
      it 'should not be allowed' do
        sign_in FactoryBot.create(:non_admin_user)
        get :index
        assert_response :found
      end
    end
  end
end
