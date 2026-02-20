# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rule section locks API' do
  let_it_be(:admin_user) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project) }

  let(:rule) { component.rules.first }

  before do
    Rails.application.reload_routes!
  end

  # ==========================================================================
  # REQUIREMENTS:
  # 1. Admin and reviewer can lock/unlock sections
  # 2. Authors cannot lock/unlock sections
  # 3. Viewers cannot lock/unlock sections
  # 4. Invalid section names are rejected
  # 5. Locking a section persists to locked_fields jsonb
  # 6. Unlocking removes section from locked_fields
  # 7. Optional comment creates audit trail
  # 8. Unauthenticated requests are rejected
  # ==========================================================================

  describe 'PATCH /rules/:id/section_locks' do
    context 'when unauthenticated' do
      it 'redirects to login' do
        patch "/rules/#{rule.id}/section_locks", params: { section: 'Title', locked: true }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when admin' do
      before do
        sign_in admin_user
        Membership.create!(user: admin_user, membership: project, role: 'admin')
      end

      it 'locks a section' do
        patch "/rules/#{rule.id}/section_locks", params: { section: 'Title', locked: true }
        expect(response).to have_http_status(:ok)
        rule.reload
        expect(rule.locked_fields['Title']).to be true
      end

      it 'unlocks a section' do
        rule.update!(locked_fields: { 'Title' => true })
        patch "/rules/#{rule.id}/section_locks", params: { section: 'Title', locked: false }
        expect(response).to have_http_status(:ok)
        rule.reload
        expect(rule.locked_fields).not_to have_key('Title')
      end

      it 'rejects invalid section name' do
        patch "/rules/#{rule.id}/section_locks", params: { section: 'Bogus', locked: true }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to match(/invalid section/i)
      end

      it 'preserves other locked sections when toggling one' do
        rule.update!(locked_fields: { 'Title' => true, 'Check' => true })
        patch "/rules/#{rule.id}/section_locks", params: { section: 'Title', locked: false }
        expect(response).to have_http_status(:ok)
        rule.reload
        expect(rule.locked_fields).to eq({ 'Check' => true })
      end

      it 'returns updated rule JSON' do
        patch "/rules/#{rule.id}/section_locks", params: { section: 'Status', locked: true }
        body = response.parsed_body
        expect(body['rule']['locked_fields']).to eq({ 'Status' => true })
        expect(body['toast']).to include('locked')
      end

      it 'creates audit record with comment' do
        expect do
          patch "/rules/#{rule.id}/section_locks",
                params: { section: 'Fix', locked: true, comment: 'Policy approved' }
        end.to change { rule.audits.count }.by(1)

        audit = rule.audits.last
        expect(audit.comment).to eq('Policy approved')
        expect(audit.audited_changes).to have_key('locked_fields')
      end

      it 'creates audit record with default comment when none provided' do
        expect do
          patch "/rules/#{rule.id}/section_locks", params: { section: 'Fix', locked: true }
        end.to change { rule.audits.count }.by(1)

        audit = rule.audits.last
        expect(audit.comment).to include('Locked section: Fix')
      end
    end

    context 'when reviewer' do
      let_it_be(:reviewer) { create(:user) }

      before do
        sign_in reviewer
        Membership.create!(user: reviewer, membership: project, role: 'reviewer')
      end

      it 'can lock a section' do
        patch "/rules/#{rule.id}/section_locks", params: { section: 'Title', locked: true }
        expect(response).to have_http_status(:ok)
      end

      it 'can unlock a section' do
        rule.update!(locked_fields: { 'Title' => true })
        patch "/rules/#{rule.id}/section_locks", params: { section: 'Title', locked: false }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when author (insufficient permissions)' do
      let_it_be(:author) { create(:user) }

      before do
        sign_in author
        Membership.create!(user: author, membership: project, role: 'author')
      end

      it 'rejects the request' do
        patch "/rules/#{rule.id}/section_locks",
              params: { section: 'Title', locked: true },
              headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:internal_server_error)
      end
    end

    context 'when viewer (insufficient permissions)' do
      let_it_be(:viewer) { create(:user) }

      before do
        sign_in viewer
        Membership.create!(user: viewer, membership: project, role: 'viewer')
      end

      it 'rejects the request' do
        patch "/rules/#{rule.id}/section_locks",
              params: { section: 'Title', locked: true },
              headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  describe 'PATCH /rules/:id/bulk_section_locks' do
    before do
      sign_in admin_user
      Membership.create!(user: admin_user, membership: project, role: 'admin')
    end

    it 'locks multiple sections at once' do
      patch "/rules/#{rule.id}/bulk_section_locks",
            params: { sections: %w[Title Status Check], locked: true }
      expect(response).to have_http_status(:ok)
      rule.reload
      expect(rule.locked_fields).to eq({ 'Title' => true, 'Status' => true, 'Check' => true })
    end

    it 'unlocks multiple sections at once' do
      rule.update!(locked_fields: { 'Title' => true, 'Status' => true, 'Check' => true })
      patch "/rules/#{rule.id}/bulk_section_locks",
            params: { sections: %w[Title Check], locked: false }
      expect(response).to have_http_status(:ok)
      rule.reload
      expect(rule.locked_fields).to eq({ 'Status' => true })
    end

    it 'rejects if any section name is invalid' do
      patch "/rules/#{rule.id}/bulk_section_locks",
            params: { sections: %w[Title Bogus], locked: true }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
