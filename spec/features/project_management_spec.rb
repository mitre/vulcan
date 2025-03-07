# filepath: /Users/alippold/github/mitre/vulcan/spec/features/project_management_spec.rb
require 'rails_helper'

RSpec.feature "Project Management", type: :feature do
  let(:user) { create(:user) }
  let(:project) { create(:project) }

  before do
    sign_in user
  end

  scenario "User creates a new project" do
    visit new_project_path
    fill_in "Name", with: "My New Project"
    click_button "Create Project"

    expect(page).to have_content("Project was successfully created.")
  end

  scenario "User manages project members" do
    visit project_path(project)
    fill_in "Email", with: "newmember@example.com"
    click_button "Invite"

    expect(page).to have_content("Invitation sent")
  end

  scenario "User can view project details" do
    visit project_path(project)
    expect(page).to have_content(project.name)
  end
end