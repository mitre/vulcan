# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENTS (B10):
# 1. Lock all should proceed even when NYD rules exist
# 2. NYD rules are SKIPPED (not locked) — only valid rules get locked
# 3. Response warns admin about skipped NYD rules
# 4. ADNM without mitigations and AIM without artifact are also skipped
# 5. Valid rules (AC, AIM with artifact, ADNM with mitigation) are locked
RSpec.describe 'Lock Controls (B10)' do
  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project) }

  before do
    Rails.application.reload_routes!
    sign_in admin
    Membership.create!(user: admin, membership: project, role: 'admin')
  end

  describe 'POST /components/:id/lock' do
    before do
      # Unlock all rules and set up a mix of statuses
      component.rules.update_all(locked: false)
      # Make first rule AC (lockable), rest stay NYD (skipped)
      component.rules.first.update_columns(status: 'Applicable - Configurable')
    end

    it 'locks valid rules even when NYD rules exist' do
      ac_count = component.rules.where(status: 'Applicable - Configurable', locked: false).count
      expect(ac_count).to be > 0

      post "/components/#{component.id}/lock",
           params: { review: { action: 'lock_control', comment: 'Lock with NYD test' } }

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      # Should be warning (not danger) since NYD rules were skipped
      expect(body['toast']['variant']).to eq('warning')
      expect(body['toast']['message']).to include('Not Yet Determined')
    end

    it 'locks AC rules and skips NYD rules' do
      ac_rule = component.rules.find_by(status: 'Applicable - Configurable')

      post "/components/#{component.id}/lock",
           params: { review: { action: 'lock_control', comment: 'Lock with NYD' } }

      expect(response).to have_http_status(:success)

      # AC rule should be locked
      ac_rule.reload
      expect(ac_rule.locked).to be(true)

      # NYD rules should NOT be locked
      nyd_unlocked = component.rules.where(status: 'Not Yet Determined', locked: false)
      expect(nyd_unlocked.count).to be > 0
    end

    it 'returns 422 when ALL rules are skippable and none can be locked' do
      # Set all rules to NYD
      component.rules.update_all(status: 'Not Yet Determined', locked: false)

      post "/components/#{component.id}/lock",
           params: { review: { action: 'lock_control', comment: 'All NYD' } }

      expect(response).to have_http_status(:unprocessable_entity)
      body = response.parsed_body
      expect(body['toast']['variant']).to eq('warning')
      expect(body['toast']['title']).to include('No controls could be locked')
    end
  end
end
