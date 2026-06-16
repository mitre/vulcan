# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'api_tokens rake tasks' do
  before(:all) do
    Rails.application.load_tasks
  end

  let_it_be(:user) { create(:user, admin: true) }

  describe 'api_tokens:revoke_idle' do
    after { Rake::Task['api_tokens:revoke_idle'].reenable }

    it 'revokes tokens unused for longer than the idle period' do
      idle_token = create(:personal_access_token, user: user, name: 'Idle')
      idle_token.update_column(:last_used_at, 100.days.ago)

      recent_token = create(:personal_access_token, user: user, name: 'Recent')
      recent_token.update_column(:last_used_at, 1.day.ago)

      never_used = create(:personal_access_token, user: user, name: 'Never used')

      expect { Rake::Task['api_tokens:revoke_idle'].invoke }
        .to output(/Revoked 1 idle token/).to_stdout

      expect(idle_token.reload.revoked_at).to be_present
      expect(recent_token.reload.revoked_at).to be_nil
      expect(never_used.reload.revoked_at).to be_nil
    end
  end

  describe 'api_tokens:revoke_expired' do
    after { Rake::Task['api_tokens:revoke_expired'].reenable }

    it 'revokes tokens past their expiration date' do
      expired = create(:personal_access_token, user: user, name: 'Expired',
                                               expires_at: 1.day.ago.to_date)
      active = create(:personal_access_token, user: user, name: 'Active',
                                              expires_at: 30.days.from_now.to_date)
      no_expiry = create(:personal_access_token, user: user, name: 'No expiry',
                                                 expires_at: nil)

      expect { Rake::Task['api_tokens:revoke_expired'].invoke }
        .to output(/Revoked 1 expired token/).to_stdout

      expect(expired.reload.revoked_at).to be_present
      expect(active.reload.revoked_at).to be_nil
      expect(no_expiry.reload.revoked_at).to be_nil
    end
  end
end
