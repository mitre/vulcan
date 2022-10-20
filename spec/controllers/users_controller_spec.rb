# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsersController, type: :controller do
  before(:all) do
    @admin_user = FactoryBot.create(:admin_user)
    @user = FactoryBot.create(:user)
  end

  after(:all) do
    User.destroy_all
  end

  describe "updating users" do
    it "should update given user when user is admin" do
      sign_in @admin_user
      put :update, params: { id: @user.id, user: { admin: false } }

      expect(flash[:notice]).to eq "Successfully updated user."
    end

    it "should not update given when user is not admin" do
      sign_in @user
      put :update, params: { id: @user.id }

      expect(response).to have_http_status(:found)
      expect(flash.alert).to have_content("Please contact an administrator")
    end
  end

  describe "removing users" do
    it "when admin" do
      sign_in @admin_user
      user1 = FactoryBot.create(:user)
      delete :destroy, params: { id: user1.id }

      expect(flash[:notice]).to eq "Successfully removed user."
    end

    it "when not admin" do
      sign_in @user
      user2 = FactoryBot.create(:user)
      delete :destroy, params: { id: user2.id }

      expect(response).to be_redirect
      expect(flash.alert).to have_content("Please contact an administrator")
    end
  end
end
