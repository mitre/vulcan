# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PersonalAccessToken do
  before { Rails.application.reload_routes! }

  let_it_be(:user) { create(:user, admin: true) }

  describe 'token generation' do
    it 'generates a vulcan_-prefixed token with SHA-256 digest on create' do
      token = described_class.create!(
        user: user,
        name: 'CI Pipeline',
        scopes: %w[read write]
      )

      expect(token.raw_token).to start_with('vulcan_')
      expect(token.raw_token.length).to be >= 43 # "vulcan_" (7) + base58(36)
      expect(token.token_digest).to be_present
      expect(token.token_digest).not_to eq(token.raw_token)
      expect(token.token_prefix).to eq(token.raw_token[0..7])
    end

    it 'does not persist the raw token — only the digest' do
      token = described_class.create!(
        user: user,
        name: 'Ephemeral check',
        scopes: %w[read]
      )
      raw = token.raw_token

      reloaded = described_class.find(token.id)
      expect(reloaded.raw_token).to be_nil
      expect(reloaded.token_digest).to be_present

      # Verify we can authenticate with the raw token
      found = described_class.authenticate(raw)
      expect(found).to eq(reloaded)
    end

    it 'hashes with salted SHA-256 using SECRET_KEY_BASE' do
      token = described_class.create!(
        user: user,
        name: 'Hash verification',
        scopes: %w[read]
      )
      raw = token.raw_token
      salt = Rails.application.secret_key_base[0..31]
      expected_digest = Digest::SHA256.base64digest("#{raw}#{salt}")

      expect(token.token_digest).to eq(expected_digest)
    end
  end

  describe 'validations' do
    it 'requires a name' do
      token = build(:personal_access_token, user: user, name: nil)
      expect(token).not_to be_valid
      expect(token.errors[:name]).to include("can't be blank")
    end

    it 'requires at least one scope' do
      token = build(:personal_access_token, user: user, scopes: [])
      expect(token).not_to be_valid
      expect(token.errors[:scopes]).to include("can't be blank")
    end

    it 'rejects invalid scopes' do
      token = build(:personal_access_token, user: user, scopes: %w[read hack])
      expect(token).not_to be_valid
      expect(token.errors[:scopes].first).to include('hack')
    end

    it 'accepts all valid scopes' do
      %w[read write admin].each do |scope|
        token = build(:personal_access_token, user: user, scopes: [scope])
        expect(token).to be_valid, "Expected scope '#{scope}' to be valid"
      end
    end

    it 'enforces max 365-day lifetime' do
      token = build(:personal_access_token, user: user,
                                            expires_at: 366.days.from_now.to_date)
      expect(token).not_to be_valid
      expect(token.errors[:expires_at].first).to include('365')
    end

    it 'allows nil expires_at (no expiry)' do
      token = build(:personal_access_token, user: user, expires_at: nil)
      expect(token).to be_valid
    end

    it 'enforces max tokens per user' do
      stub_const('PersonalAccessToken::MAX_TOKENS_PER_USER', 2)
      create_list(:personal_access_token, 2, user: user)

      third = build(:personal_access_token, user: user)
      expect(third).not_to be_valid
      expect(third.errors[:base].first).to include('maximum')
    end

    it 'validates IP allowlist entries are valid CIDRs' do
      token = build(:personal_access_token, user: user,
                                            allowed_ips: ['not-a-cidr'])
      expect(token).not_to be_valid
      expect(token.errors[:allowed_ips].first).to include('invalid')
    end

    it 'accepts valid CIDR entries' do
      token = build(:personal_access_token, user: user,
                                            allowed_ips: ['10.0.0.0/8', '192.168.1.0/24', '2001:db8::/32'])
      expect(token).to be_valid
    end

    it 'accepts nil allowed_ips (allow all)' do
      token = build(:personal_access_token, user: user, allowed_ips: nil)
      expect(token).to be_valid
    end
  end

  describe 'scopes' do
    it '.active returns only non-revoked, non-expired tokens' do
      active = create(:personal_access_token, user: user)
      _revoked = create(:personal_access_token, user: user, name: 'Revoked').tap(&:revoke!)
      _expired = create(:personal_access_token, user: user, name: 'Expired',
                                                expires_at: 1.day.ago.to_date)

      expect(described_class.active).to contain_exactly(active)
    end
  end

  describe '#revoke!' do
    it 'sets revoked_at timestamp' do
      token = create(:personal_access_token, user: user)
      expect(token.revoked_at).to be_nil

      token.revoke!
      expect(token.revoked_at).to be_within(2.seconds).of(Time.current)
      expect(token.active?).to be false
    end
  end

  describe '#active?' do
    it 'returns true for non-revoked, non-expired token' do
      token = create(:personal_access_token, user: user)
      expect(token.active?).to be true
    end

    it 'returns false for revoked token' do
      token = create(:personal_access_token, user: user)
      token.revoke!
      expect(token.active?).to be false
    end

    it 'returns false for expired token' do
      token = create(:personal_access_token, user: user,
                                             expires_at: 1.day.ago.to_date)
      expect(token.active?).to be false
    end
  end

  describe '#ip_allowed?' do
    it 'returns true when allowed_ips is nil (allow all)' do
      token = create(:personal_access_token, user: user, allowed_ips: nil)
      expect(token.ip_allowed?('1.2.3.4')).to be true
    end

    it 'returns true when allowed_ips is empty array (allow all)' do
      token = create(:personal_access_token, user: user, allowed_ips: [])
      expect(token.ip_allowed?('1.2.3.4')).to be true
    end

    it 'returns true when IP is within an allowed CIDR' do
      token = create(:personal_access_token, user: user,
                                             allowed_ips: ['10.0.0.0/8'])
      expect(token.ip_allowed?('10.1.2.3')).to be true
    end

    it 'returns false when IP is outside all allowed CIDRs' do
      token = create(:personal_access_token, user: user,
                                             allowed_ips: ['10.0.0.0/8'])
      expect(token.ip_allowed?('192.168.1.1')).to be false
    end
  end

  describe '#can?' do
    it 'returns true for matching scope' do
      token = create(:personal_access_token, user: user, scopes: %w[read])
      expect(token.can?(:read)).to be true
      expect(token.can?(:write)).to be false
    end

    it 'admin scope grants all permissions' do
      token = create(:personal_access_token, user: user, scopes: %w[admin])
      expect(token.can?(:read)).to be true
      expect(token.can?(:write)).to be true
      expect(token.can?(:admin)).to be true
    end
  end

  describe 'audit trail' do
    include_context 'with auditing'

    it 'creates an audit record on token creation' do
      expect do
        create(:personal_access_token, user: user, name: 'Audit Test')
      end.to change(Audited::Audit, :count)

      audit = Audited::Audit.where(auditable_type: 'PersonalAccessToken').last
      expect(audit.action).to eq('create')
      expect(audit.audited_changes).to have_key('name')
      expect(audit.audited_changes).to have_key('scopes')
    end

    it 'excludes token_digest and token_prefix from audit records' do
      create(:personal_access_token, user: user, name: 'Digest Exclusion Test')

      audit = Audited::Audit.where(auditable_type: 'PersonalAccessToken').last
      expect(audit.audited_changes).not_to have_key('token_digest')
      expect(audit.audited_changes).not_to have_key('token_prefix')
    end

    it 'records revocation in audit trail' do
      token = create(:personal_access_token, user: user, name: 'Revoke Audit Test')
      token.revoke!

      audit = Audited::Audit.where(auditable_type: 'PersonalAccessToken', action: 'update').last
      expect(audit.audited_changes).to have_key('revoked_at')
      expect(audit.audited_changes).not_to have_key('token_digest')
    end
  end

  describe '.authenticate' do
    it 'finds an active token by raw token string' do
      token = create(:personal_access_token, user: user)
      raw = token.raw_token

      found = described_class.authenticate(raw)
      expect(found).to eq(token)
    end

    it 'returns nil for revoked token' do
      token = create(:personal_access_token, user: user)
      raw = token.raw_token
      token.revoke!

      expect(described_class.authenticate(raw)).to be_nil
    end

    it 'returns nil for unknown token' do
      expect(described_class.authenticate('vulcan_bogus_token_here')).to be_nil
    end
  end
end
