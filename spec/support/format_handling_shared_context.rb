# frozen_string_literal: true

# Shared context for format handling tests
# Provides common test data and authentication setup
RSpec.shared_context 'format handling test setup' do
  # Shared contexts are designed to have multiple helpers - this is their purpose
  let_it_be(:admin_user) { create(:user, admin: true) }
  let_it_be(:regular_user) { create(:user, admin: false) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project) }
  let_it_be(:membership) { Membership.create!(user: admin_user, membership: project, role: 'admin') }
  let_it_be(:srg) { create(:security_requirements_guide) }

  before do
    Rails.application.reload_routes!
    sign_in admin_user
  end
end
