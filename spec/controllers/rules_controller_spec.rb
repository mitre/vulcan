# frozen_string_literal: true

require "rails_helper"

RSpec.describe RulesController, type: :controller do
  before(:all) do
    @admin_user = FactoryBot.create(:admin_user)
    @user = FactoryBot.create(:user)
    @rule = FactoryBot.create(:rule)
  end

  after(:all) do
    User.destroy_all
    Rule.destroy_all
    Component.destroy_all
    SrgRule.destroy_all
  end

  describe "searching for rules" do
    it "should ensure the user is logged in" do
      get :search, params: { q: {} }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "should return rules that match the query" do
      @rule.version = "SRG-OS-000001-GPOS-00001"
      @rule.save!
      sign_in @admin_user
      get :search, params: { q: @rule.version }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["rules"].map(&:first)).to eq [@rule.id]
    end
  end

  describe "showing rules of a component" do
    let(:component_id) { Component.first.id }
    it "should ensure the user is logged in" do
      get :index, params: { component_id: "" }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "should prevent unauthorized users to view the rules" do
      sign_in @user
      get :index, params: { component_id: component_id }

      expect(response).to have_http_status(:found)
      expect(flash.alert).to have_content("Please contact an administrator")
    end

    it "should allow authorized users to view the rules" do
      sign_in @admin_user
      get :index, params: { component_id: component_id }

      expect(response).to have_http_status(:success)
      expect(assigns(:rules).count).to eq(Component.first.rules.count)
    end
  end

  describe "Showing a rule" do
    it "should ensure the user is logged in" do
      get :show, params: { id: "" }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "should prevent unauthorized users to view the rule" do
      sign_in @user
      get :show, params: { id: @rule.id }

      expect(response).to have_http_status(:found)
      expect(flash.alert).to have_content("Please contact an administrator")
    end

    it "should allow authorized users to view the rule" do
      sign_in @admin_user
      get :show, params: { id: @rule.id }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).keys).to include(*%w[histories satisfies satisfied_by])
    end
  end

  describe "creating a rule" do
    let(:component_id) { Component.first.id }
    let(:project_id) { Component.first.project_id }
    it "should not create rule if user is not signed in" do
      expect { post :create, params: { component_id: component_id } }.not_to change(Rule, :count)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "should successfully create a rule if signed in as admin user" do
      sign_in @admin_user
      expect do
        post(:create, params: { component_id: component_id, rule: { component_id: component_id } })
      end.to change(Rule, :count).by(1)
      expect(response).to have_http_status(:success)
    end

    it "should successfully duplicate a rule if user has author permission" do
      @user.memberships << Membership.new(membership_type: "Project", membership_id: project_id, role: "author")
      sign_in @user
      expect do
        post(:create, params: { component_id: component_id, rule: { id: @rule.id, duplicate: true } })
      end.to change(Rule, :count).by(1)
    end

    it "should prevent user with no permissions to create a rule" do
      user = FactoryBot.create(:user)
      user.memberships << Membership.new(membership_type: "Project", membership_id: project_id, role: "viewer")
      sign_in user
      post :create, params: { component_id: component_id, rule: { component_id: component_id } }

      expect(response).to be_redirect
      expect(flash.alert).to have_content("Please contact an administrator")
    end
  end

  describe "updating a rule" do
    let(:project_id) { Component.first.project_id }
    it "should ensure the user is logged in" do
      put :update, params: { id: "", rule: {} }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "should successfully update a rule if signed in as admin user" do
      sign_in @admin_user
      put :update, format: :json, params: { id: @rule.id, rule: { rule_severity: "unknown" } }
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["toast"]).to eq("Successfully updated control.")
    end

    it "should successfully update a rule if user has author permission" do
      @user.memberships << Membership.new(membership_type: "Project", membership_id: project_id, role: "author")
      sign_in @user
      put :update, format: :json, params: { id: @rule.id, rule: { rule_severity: "unknown" } }
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["toast"]).to eq("Successfully updated control.")
    end

    it "should prevent user with no valid permissions to update a rule" do
      user = FactoryBot.create(:user)
      user.memberships << Membership.new(membership_type: "Project", membership_id: project_id, role: "viewer")
      sign_in user
      put :update, params: { id: @rule.id, rule: { rule_severity: "unknown" } }

      expect(response).to be_redirect
      expect(flash.alert).to have_content("Please contact an administrator")
    end
  end

  describe "deleting a rule" do
    it "should ensure the user is logged in" do
      delete :destroy, params: { id: @rule.id }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "should allow admin users to delete a rule" do
      sign_in @admin_user
      delete :destroy, format: :json, params: { id: @rule.id }

      expect(JSON.parse(response.body)["toast"]).to eq("Successfully deleted control.")
    end

    it "should prevent non admin users from deleting a rule" do
      sign_in @user
      delete :destroy, params: { id: @rule.id }

      expect(response).to be_redirect
      expect(flash.alert).to have_content("Please contact an administrator")
    end
  end
end
