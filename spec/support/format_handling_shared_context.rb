# frozen_string_literal: true

# Shared context for format handling tests
# Provides common test data and authentication setup
RSpec.shared_context 'format handling test setup' do
  let(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }
  let(:project) { create(:project) }
  let(:component) { create(:component, project: project) }
  let(:membership) { Membership.create!(user: admin_user, membership: project, role: 'admin') }
  let(:srg) { create(:security_requirements_guide) }

  before do
    Rails.application.reload_routes!
    sign_in admin_user
  end
end