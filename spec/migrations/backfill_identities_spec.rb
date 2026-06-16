# frozen_string_literal: true

require 'rails_helper'

# Tests the backfill migration that creates Identity rows for existing
# non-local users. Must be idempotent (re-run safe) and reversible.
RSpec.describe 'BackfillIdentities migration' do
  # The migration class — loaded from the migration file
  let(:migration_class) do
    require Rails.root.join('db/migrate/20260614140000_backfill_identities')
    BackfillIdentities
  end

  let!(:oidc_user) { create(:user, provider: 'oidc', uid: 'backfill-oidc-1', email: 'bf-oidc@example.com') }
  let!(:ldap_user) { create(:user, provider: 'ldap', uid: 'backfill-ldap-1', email: 'bf-ldap@example.com') }
  let!(:local_user) { create(:user, provider: nil, uid: nil, email: 'bf-local@example.com') }

  it 'creates one Identity per non-local user' do
    expect { migration_class.new.up }
      .to change { Identity.where(user: [oidc_user, ldap_user]).count }.by(2)

    oidc_identity = Identity.find_by(user: oidc_user)
    expect(oidc_identity).to have_attributes(
      provider: 'oidc',
      uid: 'backfill-oidc-1',
      email: 'bf-oidc@example.com'
    )

    ldap_identity = Identity.find_by(user: ldap_user)
    expect(ldap_identity).to have_attributes(provider: 'ldap', uid: 'backfill-ldap-1')
  end

  it 'skips local-only users (provider nil)' do
    migration_class.new.up
    expect(Identity.where(user: local_user).count).to eq(0)
  end

  it 'is idempotent — re-run does not create duplicates' do
    migration_class.new.up
    expect { migration_class.new.up }.not_to change(Identity, :count)
  end

  it 'is reversible — down removes backfilled rows' do
    migration_class.new.up
    expect { migration_class.new.down }.to change { Identity.where(user: [oidc_user, ldap_user]).count }.to(0)
  end
end
