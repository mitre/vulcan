# frozen_string_literal: true

require "rails_helper"

RSpec.describe ComponentsController, type: :controller do
  before(:all) do
    @admin_user = FactoryBot.create(:admin_user)
    @user = FactoryBot.create(:user)
    @component = FactoryBot.create(:component)
    @released_component = FactoryBot.create(:released_component)
    @project_id = Project.first.id
    @srg_id = SecurityRequirementsGuide.first.id
  end

  after(:all) do
    User.destroy_all
    Project.destroy_all
    Component.destroy_all
    SecurityRequirementsGuide.destroy_all
  end

  describe "viewing all released components" do
    it "should ensure the user is logged in" do
      get :index

      expect(response).to redirect_to(new_user_session_path)
    end

    it "should return all released components" do
      sign_in @user
      get :index

      expect(response).to have_http_status(:success)
      expect(JSON.parse(assigns(:components_json)).all? { |c| c["released"] == true }).to be_truthy
    end
  end

  describe "searching for components" do
    it "should ensure the user is logged in" do
      get :search, params: { q: {} }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "should return components that match the query" do
      sign_in @admin_user
      get :search, params: { q: @component.based_on.srg_id }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["components"].map(&:first)).to eq Component.where(
                                                                           security_requirements_guide_id: @srg_id,
                                                                         )
                                                                           .pluck(:id)
    end
  end

  describe "showing a component" do
    it "should ensure the user is logged in" do
      get :show, params: { id: @component.id }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "should allow admin to view an unreleased component with admin actions" do
      sign_in @admin_user
      get :show, format: :json, params: { id: @component.id }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).keys).to include(*%w[histories memberships metadata inherited_memberships
                                                            available_members rules reviews])
    end

    it "should allow admin to view a released component with admin actions" do
      sign_in @admin_user
      get :show, format: :json, params: { id: @released_component.id }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).keys).to include(*%w[histories memberships metadata inherited_memberships
                                                            available_members rules reviews])
    end

    it "should not allow users with no permissions to view an non released component" do
      sign_in @user
      get :show, format: :json, params: { id: @component.id }

      expect(response).to have_http_status(:internal_server_error)
    end

    it "should allow non admin members of a project to view a project's component" do
      @user.memberships << Membership.new(membership_type: "Project", membership_id: @project_id, role: "viewer")
      sign_in @user
      get :show, format: :json, params: { id: @component.id }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).keys).to include(*%w[rules reviews])
      expect(JSON.parse(response.body).keys).to include(*%w[histories memberships metadata inherited_memberships
                                                            available_members])
    end

    it "should allow non admin users to view a released component with viewer actions" do
      sign_in @user
      get :show, format: :json, params: { id: @released_component.id }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).keys).to include(*%w[rules reviews])
      expect(JSON.parse(response.body).keys).not_to include(*%w[histories memberships metadata inherited_memberships
                                                                available_members])
    end
  end

  describe "creating a component" do
    it "should ensure the user is logged in" do
      post :create, params: { project_id: @project_id, component: { name: "comp 1", prefix: "ABCD-00",
                                                                   security_requirements_guide_id: @srg_id } }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "should not create component if user is not admin of project" do
      sign_in @user
      post :create, params: { project_id: @project_id, component: { name: "comp 1", prefix: "ABCD-00",
                                                                   security_requirements_guide_id: @srg_id } }

      expect(response).to have_http_status(:found)
    end

    it "should create a new component" do
      sign_in @admin_user
      post :create, params: { project_id: @project_id, component: { name: "comp 1", prefix: "ABCD-00",
                                                                   security_requirements_guide_id: @srg_id } }

      expect(response).to have_http_status(:success)
    end
  end

  describe "updating a component" do
    it "should ensure the user is logged in" do
      put :update, params: { project_id: @project_id, id: @component.id }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "should not update component if user does not have permission" do
      sign_in @user
      put :update, params: { project_id: @project_id, id: @component.id }

      expect(response).to have_http_status(:found)
    end

    it "should update a component if user has permission" do
      sign_in @admin_user
      put :update, params: { project_id: @project_id, id: @component.id, component: { name: "comp 2" } }

      expect(response).to have_http_status(:success)
    end
  end

  describe "exporting a component" do
    it "should ensure the user is logged in" do
      get :export, params: { id: @component.id, type: "csv" }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "should only allow inspec and csv export" do
      sign_in @user
      get :export, format: :json, params: { id: @component.id, type: "excel" }

      expect(response).to have_http_status(:bad_request)
    end

    it "should support csv export" do
      sign_in @user
      csv_options = { filename: "#{@component.project.name}-#{@component.prefix}.csv" }

      expect(@controller).to receive(:send_data).with(@component.csv_export, csv_options) { @controller.render nothing: true }
      get :export, params: { id: @component.id, type: "csv" }
    end

    it "should support inspec export" do
      sign_in @user
      get :export, format: :json, params: { id: @component.id, type: "inspec" }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "deleting a component" do
    it "should ensure the user is logged in" do
      delete :destroy, params: { project_id: @project_id, id: @component.id }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "should not delete component if user does not have permission" do
      sign_in @user
      delete :destroy, params: { project_id: @project_id, id: @component.id }

      expect(response).to have_http_status(:found)
    end

    it "should delete component if user has permission" do
      sign_in @admin_user
      delete :destroy, params: { project_id: @project_id, id: @component.id }

      expect(response).to have_http_status(:success)
    end
  end
end
