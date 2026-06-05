# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserBlueprint do
  let_it_be(:user) { create(:user, admin: true) }

  describe 'default view (dropdowns, member lists, navbar locked_users)' do
    subject(:result) { described_class.render_as_hash(user) }

    it 'includes only id, name, email' do
      expect(result.keys).to match_array(%i[id name email])
    end

    it 'does NOT include sensitive fields' do
      expect(result.keys).not_to include(:encrypted_password, :reset_password_token,
                                         :admin, :locked_at, :failed_attempts)
    end
  end

  describe ':profile view' do
    subject(:result) { described_class.render_as_hash(user, view: :profile) }

    it 'includes fields needed by profile and password pages' do
      expect(result.keys).to match_array(%i[id name email provider slack_user_id unconfirmed_email])
    end

    it 'does NOT include admin status or sign-in tracking' do
      expect(result.keys).not_to include(:admin, :last_sign_in_at, :failed_attempts,
                                         :locked_at, :encrypted_password)
    end
  end

  describe ':admin view' do
    subject(:result) { described_class.render_as_hash(user, view: :admin) }

    it 'includes all admin-visible fields' do
      expect(result.keys).to match_array(%i[id name email provider admin last_sign_in_at
                                            failed_attempts locked_at])
    end

    it 'does NOT include Devise internals' do
      expect(result.keys).not_to include(:encrypted_password, :reset_password_token,
                                         :reset_password_sent_at, :confirmation_token,
                                         :unlock_token)
    end

    it 'returns correct values' do
      expect(result[:id]).to eq(user.id)
      expect(result[:name]).to eq(user.name)
      expect(result[:email]).to eq(user.email)
      expect(result[:admin]).to be(true)
    end
  end
end
