# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: the revert endpoint's request surface is audit_id, fields
# (PLURAL — an array of field names), and audit_comment. These pins enforce
# the contract the action actually reads. Reverting restores the named
# fields' prior values and records the caller's comment on the audit trail.
# ==========================================================================
RSpec.describe 'Rule history revert' do
  include_context 'with auditing'

  let_it_be(:admin_user) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project) }

  let(:rule) { component.rules.first }
  let(:json_headers) { { 'Accept' => 'application/json', 'Content-Type' => 'application/json' } }

  before do
    Rails.application.reload_routes!
    sign_in admin_user
  end

  describe 'POST /rules/:id/revert' do
    it 'reverts only the named fields and records the audit comment' do
      original_title = rule.title
      rule.update!(title: 'Changed Title', audit_comment: 'change for revert test')
      change_audit = rule.audits.where(action: 'update').last
      expect(change_audit.audited_changes).to have_key('title')

      post "/rules/#{rule.id}/revert",
           params: { audit_id: change_audit.id, fields: ['title'],
                     audit_comment: 'Reverting the title change' }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('toast', 'title')).to eq('History reverted.')
      expect(rule.reload.title).to eq(original_title)
      expect(rule.audits.last.comment).to eq('Reverting the title change')
    end

    it 'rejects a field name absent from the named history entry' do
      rule.update!(title: 'Another Change', audit_comment: 'setup')
      change_audit = rule.audits.where(action: 'update').last

      post "/rules/#{rule.id}/revert",
           params: { audit_id: change_audit.id, fields: ['fixtext'],
                     audit_comment: 'wrong field' }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('toast', 'title')).to eq('Could not revert history.')
      expect(response.parsed_body.dig('toast', 'message').join)
        .to include('Fixtext) does not exist in this history')
    end

    it 'returns 404 for an unknown audit id (RecordNotFound path)' do
      post "/rules/#{rule.id}/revert",
           params: { audit_id: 0, fields: ['title'], audit_comment: 'missing audit' }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
