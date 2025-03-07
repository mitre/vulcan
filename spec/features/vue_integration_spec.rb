require 'rails_helper'

RSpec.describe "Vue.js Integration", type: :system do
  before do
    driven_by(:selenium_chrome_headless)
  end

  it "loads Vue.js components" do
    visit '/' # Adjust the path to a page where your Vue component is loaded
    expect(page).to have_content('My Component') # Adjust the content to match your component
  end
end
