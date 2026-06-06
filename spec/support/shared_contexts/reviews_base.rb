# frozen_string_literal: true

# Shared setup for all reviews REQUEST specs.
# Provides project, SRG, component (comment_phase=open),
# rule, and route reload. Each split file includes this context.
RSpec.shared_context 'reviews request base setup' do
  # Must be first user created — absorbs first-user-admin promotion
  # (Settings.admin_bootstrap.first_user_admin defaults true) so test
  # users don't accidentally become admin and bypass role checks.
  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg, comment_phase: 'open') }
  let_it_be(:rule) { component.rules.first }

  before { Rails.application.reload_routes! }
end
