# frozen_string_literal: true

require 'rails_helper'

# Connected Accounts: signed-in user connects a new provider identity.
# The full connect flow (initiate_link → OmniAuth → handle_identity_link)
# requires session[:link_in_progress] to persist across the OmniAuth mock
# redirect chain, which ActiveRecord session store doesn't do reliably in
# RSpec request specs. The flow is proven via Playwright live testing.
# These tests verify the model layer that the connect flow calls.
RSpec.describe 'Connect identity' do
  let(:user) { create(:user, provider: 'okta', uid: 'existing-okta') }

  it 'link_identity! creates a new identity without removing existing ones' do
    create(:identity, user: user, provider: 'okta', uid: 'existing-okta')

    user.link_identity!(provider: 'login_gov', uid: 'lg-connect', email: user.email)

    expect(user.identities.count).to eq(2)
    expect(user.identities.pluck(:provider)).to contain_exactly('okta', 'login_gov')
  end

  it 'link_identity! refuses when (provider, uid) belongs to another user' do
    other_user = create(:user, email: 'other@example.com')
    create(:identity, user: other_user, provider: 'login_gov', uid: 'taken-uid')

    expect do
      user.link_identity!(provider: 'login_gov', uid: 'taken-uid', email: user.email)
    end.to raise_error(User::ProviderConflictError)
  end
end
