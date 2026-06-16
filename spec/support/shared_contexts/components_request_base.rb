# frozen_string_literal: true

RSpec.shared_context 'components request base setup' do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project) }
  let_it_be(:membership) { Membership.create!(user: user, membership: project, role: 'admin') }

  let(:application_json) { 'application/json' }

  before do
    Rails.application.reload_routes!
    sign_in user
  end
end
