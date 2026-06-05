# frozen_string_literal: true

# Shared setup for all reviews request specs.
# Provides anchor admin, project, SRG, component (comment_phase=open),
# rule, and route reload. Each split file includes this context.
RSpec.shared_context 'reviews base setup' do
  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg, comment_phase: 'open') }
  let(:rule) { component.rules.first }

  before { Rails.application.reload_routes! }
end
