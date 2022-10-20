# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SecurityRequirementsGuidesController, type: :controller do
  before(:all) do
    @admin_user = FactoryBot.create(:admin_user)
    @user = FactoryBot.create(:user)
    2.times.each { FactoryBot.create(:security_requirements_guide) }
  end

  after(:all) do
    User.destroy_all
    SecurityRequirementsGuide.destroy_all
  end

  describe 'viewing SRGs' do
    it 'should ensure a user is logged in' do
      get :index

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'should return a list of SRGs' do
      [@admin_user, @user].each do |u|
        sign_in u
        get :index, format: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to eq SecurityRequirementsGuide.all.order(:srg_id, :version)
                                                             .select(:id, :srg_id, :title, :version, :release_date)
                                                             .to_json
      end
    end
  end

  describe 'creating SRGs' do
    it 'should ensure a user is logged in' do
      post :create, params: { file: '' }

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'should create the SRG when user is admin' do
      sign_in @admin_user
      file = fixture_file_upload('./spec/fixtures/files/U_Web_Server_V2R3_Manual-xccdf.xml', 'text/xml')
      post :create, params: { file: file }

      expect(response).to have_http_status(:success)
    end

    it 'should not create SRG when user is not admin' do
      sign_in @user
      post :create

      expect(response).to be_redirect
      expect(flash.alert).to have_content('Please contact an administrator')
    end
  end

  describe 'removing SRGs' do
    it 'should ensure a user is logged in' do
      delete :destroy, params: { id: 1 }

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'when admin' do
      sign_in @admin_user
      delete :destroy, params: { id: SecurityRequirementsGuide.first.id }

      expect(flash[:notice]).to eq 'Successfully removed SRG.'
    end

    it 'when not admin' do
      sign_in @user
      delete :destroy, params: { id: 1 }

      expect(response).to be_redirect
      expect(flash.alert).to have_content('Please contact an administrator')
    end
  end
end
