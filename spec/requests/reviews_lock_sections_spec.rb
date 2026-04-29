# frozen_string_literal: true

require 'rails_helper'

# Coverage for PATCH /components/:component_id/lock_sections.
# Sister-controller action to lock_controls; both share the
# render-inside-loop / partial-write antipattern history.
RSpec.describe 'Lock Sections' do
  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg) }
  let_it_be(:reviewer) { create(:user) }

  before do
    Rails.application.reload_routes!
    Membership.find_or_create_by!(user: reviewer, membership: component) do |m|
      m.role = 'reviewer'
    end
    sign_in reviewer
    component.rules.update_all(locked: false, locked_fields: {})
  end

  describe 'PATCH /components/:component_id/lock_sections' do
    it 'locks the requested sections on every unlocked rule' do
      expect do
        patch "/components/#{component.id}/lock_sections",
              params: { sections: %w[Title], locked: true, comment: 'lock title' }
      end.to change { component.rules.first.reload.locked_fields['Title'] }.from(nil).to(true)

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('success')
    end

    it 'rejects an invalid section name' do
      patch "/components/#{component.id}/lock_sections",
            params: { sections: %w[NotAField], locked: true, comment: 'bogus' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to include('Invalid sections')
    end

    it 'rolls back ALL prior locks if a later rule.update! fails (no partial writes)' do
      # The pre-fix controller had no transaction wrap — if rule N+1's update!
      # raised, rules 1..N were already committed and the user got a 500.
      # Force the SECOND rule's update! to raise, expect the FIRST rule's
      # locked_fields to be rolled back too.
      rules = component.rules.order(:id).to_a
      expect(rules.size).to be >= 2, 'spec needs at least 2 rules in the component'

      original_update = Rule.instance_method(:update!)
      call_count = 0
      allow_any_instance_of(Rule).to receive(:update!) do |instance, *args|
        call_count += 1
        raise ActiveRecord::StatementInvalid, 'forced on second call' if call_count == 2

        original_update.bind_call(instance, *args)
      end

      patch "/components/#{component.id}/lock_sections",
            params: { sections: %w[Title], locked: true, comment: 'partial-write test' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig('toast', 'variant')).to eq('danger')

      # Critical: the FIRST rule's update was rolled back too — no partial write
      rules.each do |rule|
        expect(rule.reload.locked_fields['Title']).to be_nil,
                                                      "Rule #{rule.id} retained Title=true after rollback"
      end
    end
  end
end
