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

    it 'returns 422 when the fields param is missing, not a swallowed server error' do
      rule.update!(title: 'Missing Fields Setup', audit_comment: 'setup')
      change_audit = rule.audits.where(action: 'update').last

      post "/rules/#{rule.id}/revert",
           params: { audit_id: change_audit.id, audit_comment: 'no fields given' }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('toast', 'title')).to eq('Could not revert history.')
      expect(response.parsed_body.dig('toast', 'message').join)
        .to include('Fields to revert are required')
    end

    it 'regenerates stig InSpec code from the post-revert state' do
      original_title = rule.title
      rule.update!(title: 'Drifted Title For Inspec', audit_comment: 'setup drift')
      change_audit = rule.audits.where(action: 'update').last

      post "/rules/#{rule.id}/revert",
           params: { audit_id: change_audit.id, fields: ['title'],
                     audit_comment: 'restore the title' }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:ok)
      reverted = rule.reload
      expect(reverted.title).to eq(original_title)
      # The after-save InSpec regeneration must read the reverted state —
      # a stale in-memory instance regenerates the control from pre-revert
      # attributes and silently overwrites the correct file.
      expect(reverted.inspec_control_file).to include(original_title)
      expect(reverted.inspec_control_file).not_to include('Drifted Title For Inspec')
    end

    # Boundary: the destroy-revert case can re-create RuleDescription,
    # DisaRuleDescription, and Check rows. Check is audited on update only,
    # so its destroy branch is defensive — it becomes reachable only if
    # Check auditing ever expands to destroys.
    it 'reverts a destroyed description by re-creating it' do
      description = RuleDescription.create!(base_rule: rule, description: 'A description worth restoring')
      description.destroy!
      destroy_audit = rule.own_and_associated_audits.where(action: 'destroy').last
      expect(destroy_audit.auditable_type).to eq('RuleDescription')

      post "/rules/#{rule.id}/revert",
           params: { audit_id: destroy_audit.id, fields: [],
                     audit_comment: 'Restore the deleted description' }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(rule.reload.rule_descriptions.pluck(:description)).to include('A description worth restoring')
    end
  end

  # Authored SRG requirements are audited through the same machinery, so
  # history revert applies to both document kinds — one path, kind-agnostic.
  describe 'POST /rules/:id/revert for an authored SRG requirement' do
    let_it_be(:srg_component) do
      create(:component, :skip_rules, project: project, document_type: 'srg',
                                      prefix: 'RVRT-00', name: 'Revert SRG', title: 'Revert SRG')
    end
    let(:requirement) do
      create(:srg_rule, :authored, component: srg_component, rule_id: '000001',
                                   title: 'Original requirement title')
    end

    it 'reverts an audited field change and records the revert on the trail' do
      requirement.update!(title: 'Amended requirement title', audit_comment: 'setup change')
      change_audit = requirement.audits.where(action: 'update').last
      expect(change_audit.audited_changes).to have_key('title')

      post "/rules/#{requirement.id}/revert",
           params: { audit_id: change_audit.id, fields: ['title'],
                     audit_comment: 'Restore the original wording' }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('toast', 'title')).to eq('History reverted.')
      expect(requirement.reload.title).to eq('Original requirement title')
      expect(requirement.audits.last.comment).to eq('Restore the original wording')
    end

    it 'rejects a field name absent from the history entry loudly, not silently' do
      requirement.update!(title: 'Another amendment', audit_comment: 'setup')
      change_audit = requirement.audits.where(action: 'update').last

      post "/rules/#{requirement.id}/revert",
           params: { audit_id: change_audit.id, fields: ['inspec_control_body'],
                     audit_comment: 'a field this history never carried' }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('toast', 'title')).to eq('Could not revert history.')
      expect(response.parsed_body.dig('toast', 'message').join)
        .to include('does not exist in this history')
    end

    it 'reports a revert the row validations refuse, never a silent success' do
      # Restoring the justification to blank while the status stays Not
      # Applicable violates the justification-required validation — the
      # endpoint must say so, not toast success over an unchanged row.
      requirement.update!(status: 'Not Applicable',
                          status_justification: 'Delegated to the platform.',
                          audit_comment: 'determine as NA')
      change_audit = requirement.audits.where(action: 'update').last
      expect(change_audit.audited_changes).to have_key('status_justification')

      post "/rules/#{requirement.id}/revert",
           params: { audit_id: change_audit.id, fields: ['status_justification'],
                     audit_comment: 'restore the blank justification' }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('toast', 'title')).to eq('Could not revert history.')
      expect(requirement.reload.status_justification).to eq('Delegated to the platform.')
    end
  end
end
