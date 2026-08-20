# frozen_string_literal: true

require 'rails_helper'

# Identity model — one row per (provider, uid) linked to a user.
# The source of truth for which external identities a user holds.
# users.provider/uid are denormalized "last-used" caches for backward compat.
RSpec.describe Identity do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:identity) }

    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_presence_of(:uid) }
  end

  describe 'unique constraint (provider, uid)' do
    let!(:existing) { create(:identity, provider: 'okta', uid: 'okta-123') }

    it 'rejects a duplicate (provider, uid) pair' do
      duplicate = build(:identity, provider: 'okta', uid: 'okta-123', user: create(:user))
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:uid]).to include('has already been taken')
    end

    it 'allows the same uid on a different provider' do
      different_provider = build(:identity, provider: 'login_gov', uid: 'okta-123', user: create(:user))
      expect(different_provider).to be_valid
    end
  end

  describe 'cascade delete' do
    it 'destroys identities when the user is destroyed' do
      user = create(:user)
      create(:identity, user: user, provider: 'okta', uid: 'del-1')
      create(:identity, user: user, provider: 'login_gov', uid: 'del-2')
      expect { user.destroy! }.to change(described_class, :count).by(-2)
    end
  end
end
