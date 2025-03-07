# filepath: /Users/alippold/github/mitre/vulcan/spec/requests/projects_spec.rb
require 'rails_helper'

RSpec.describe "Projects", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  describe "GET /projects" do
    it "returns http success" do
      get projects_path
      expect(response).to have_http_status(:success)
    end

    it "renders the index template" do
      get projects_path
      expect(response).to render_template(:index)
    end
  end

  describe "POST /projects" do
    it "creates a new project" do
      expect {
        post projects_path, params: { project: { name: "Test Project" } }
      }.to change(Project, :count).by(1)
      expect(response).to redirect_to(project_path(Project.last))
    end

    it "redirects to the created project" do
      post projects_path, params: { project: { name: "Test Project" } }
      expect(response).to redirect_to(project_path(Project.last))
    end

    it "shows a success message" do
      post projects_path, params: { project: { name: "Test Project" } }
      expect(flash[:notice]).to eq("Project was successfully created.")
    end
  end
end