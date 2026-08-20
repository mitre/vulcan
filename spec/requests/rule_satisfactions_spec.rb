# frozen_string_literal: true

require 'rails_helper'

# Coverage for RuleSatisfactionsController#create + #destroy.
# Both actions do a join-table mutation followed by a save on the
# associated rule (to trigger inspec callbacks). Pre-fix these were
# two separate DB calls with no transaction — a save failure left the
# join table out of sync with the model state.
RSpec.describe 'Rule Satisfactions' do
  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg) }
  let_it_be(:author) { create(:user) }

  let(:rule_a) { component.rules[0] }
  let(:rule_b) { component.rules[1] }

  before do
    Rails.application.reload_routes!
    Membership.find_or_create_by!(user: author, membership: project) do |m|
      m.role = 'author'
    end
    sign_in author
  end

  describe 'POST /rules/:rule_id/rule_satisfactions/:id (create)' do
    it 'rolls back the join-table insert if the rule save raises' do
      # Force the save callback to raise. Pre-fix the controller did:
      #   @rule.satisfied_by << @satisfied_by_rule   # join-table INSERT commits
      #   @satisfied_by_rule.save                    # raises → user gets 500,
      #                                              # but the join survives
      allow_any_instance_of(Rule).to receive(:save!).and_raise(
        ActiveRecord::StatementInvalid, 'forced'
      )

      expect do
        post '/rule_satisfactions',
             params: { rule_id: rule_a.id, satisfied_by_rule_id: rule_b.id }
      end.not_to change(RuleSatisfaction, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(rule_a.reload.satisfied_by).not_to include(rule_b)
    end
  end

  describe 'ADNM automation on create' do
    it 'sets child rule status to ADNM when satisfaction created' do
      post '/rule_satisfactions',
           params: { rule_id: rule_a.id, satisfied_by_rule_id: rule_b.id }

      expect(response).to have_http_status(:ok)
      rule_a.reload
      expect(rule_a.status).to eq('Applicable - Does Not Meet')
    end

    it 'populates child mitigation with canonical DISA format' do
      post '/rule_satisfactions',
           params: { rule_id: rule_a.id, satisfied_by_rule_id: rule_b.id }

      rule_a.reload
      drd = rule_a.disa_rule_descriptions.first
      expect(drd.mitigations).to include("fully mitigated by #{component.prefix}-#{rule_b.rule_id}")
      expect(drd.mitigations).to include('overall risk is fully mitigated')
    end

    it 'populates child status_justification referencing the parent' do
      post '/rule_satisfactions',
           params: { rule_id: rule_a.id, satisfied_by_rule_id: rule_b.id }

      rule_a.reload
      expect(rule_a.status_justification).to include("#{component.prefix}-#{rule_b.rule_id}")
    end

    it 'does NOT clear check or fix content' do
      original_fixtext = rule_a.fixtext
      original_check = rule_a.checks.first&.content

      post '/rule_satisfactions',
           params: { rule_id: rule_a.id, satisfied_by_rule_id: rule_b.id }

      rule_a.reload
      expect(rule_a.fixtext).to eq(original_fixtext)
      expect(rule_a.checks.first&.content).to eq(original_check)
    end
  end

  describe 'ADNM automation on destroy — resets to NYD' do
    include_context 'with auditing'

    before do
      # Create the satisfaction first (which sets ADNM)
      rule_a.satisfied_by << rule_b
      rule_b.save!
      rule_a.update!(status: 'Applicable - Does Not Meet',
                     status_justification: 'Satisfied by parent')
      rule_a.disa_rule_descriptions.first&.update!(mitigations: 'Fully mitigated')
    end

    it 'restores original pre-nesting status from audit trail' do
      # The ADNM automation audit comment records "(was: Applicable - Does Not Meet)"
      # because the before block set it to ADNM. The original was AC before that.
      # Create a fresh nesting with a known pre-nesting status via the full cycle.
      rule_a.satisfied_by.delete_all
      rule_a.update!(status: 'Applicable - Configurable')

      # Nest via API (records audit with "was: AC")
      post '/rule_satisfactions',
           params: { rule_id: rule_a.id, satisfied_by_rule_id: rule_b.id }
      expect(response).to have_http_status(:ok)
      expect(rule_a.reload.status).to eq('Applicable - Does Not Meet')

      # Unnest via API (reads audit to find "was: AC")
      delete "/rule_satisfactions/#{rule_b.id}",
             params: { rule_id: rule_a.id, satisfied_by_rule_id: rule_b.id }
      expect(response).to have_http_status(:ok)
      expect(rule_a.reload.status).to eq('Applicable - Configurable')
    end

    it 'falls back to NYD when no nesting audit exists' do
      delete "/rule_satisfactions/#{rule_b.id}",
             params: { rule_id: rule_a.id, satisfied_by_rule_id: rule_b.id }

      expect(response).to have_http_status(:ok)
      rule_a.reload
      expect(rule_a.status).to eq('Not Yet Determined')
    end

    it 'clears mitigation and status_justification on removal' do
      delete "/rule_satisfactions/#{rule_b.id}",
             params: { rule_id: rule_a.id, satisfied_by_rule_id: rule_b.id }

      rule_a.reload
      expect(rule_a.status_justification).to be_blank
      drd = rule_a.disa_rule_descriptions.first
      expect(drd&.mitigations).to be_blank
    end
  end

  describe 'round-trip content preservation — nest then unnest' do
    include_context 'with auditing'

    it 'preserves user-edited check/fix/title content and restores original status through nest + unnest cycle' do
      original_fixtext = 'Custom fix text the user spent hours writing'
      original_title = 'Custom requirement title'
      original_check = rule_a.checks.first&.content || 'Original check content'
      rule_a.update!(fixtext: original_fixtext, title: original_title, status: 'Applicable - Configurable')
      rule_a.checks.first&.update!(content: original_check)

      # Nest: creates satisfaction, sets ADNM
      post '/rule_satisfactions',
           params: { rule_id: rule_a.id, satisfied_by_rule_id: rule_b.id }
      expect(response).to have_http_status(:ok)

      rule_a.reload
      expect(rule_a.status).to eq('Applicable - Does Not Meet')
      # Content still there even though ADNM hides it in the UI
      expect(rule_a.fixtext).to eq(original_fixtext)
      expect(rule_a.title).to eq(original_title)
      expect(rule_a.checks.first&.content).to eq(original_check)

      # Unnest: removes satisfaction, restores ORIGINAL status (AC, not NYD)
      delete "/rule_satisfactions/#{rule_b.id}",
             params: { rule_id: rule_a.id, satisfied_by_rule_id: rule_b.id }
      expect(response).to have_http_status(:ok)

      rule_a.reload
      expect(rule_a.status).to eq('Applicable - Configurable')
      # Content MUST still be intact — user's work preserved
      expect(rule_a.fixtext).to eq(original_fixtext)
      expect(rule_a.title).to eq(original_title)
      expect(rule_a.checks.first&.content).to eq(original_check)
    end
  end

  describe 'DELETE /rule_satisfactions/:id (destroy)' do
    before do
      rule_a.satisfied_by << rule_b
      rule_b.save!
    end

    it 'rolls back the join-table delete if the rule save raises' do
      # Same pattern in destroy: the join row is removed first, then save
      # runs. A save failure used to leave the join table out of sync.
      allow_any_instance_of(Rule).to receive(:save!).and_raise(
        ActiveRecord::StatementInvalid, 'forced'
      )

      expect do
        delete "/rule_satisfactions/#{rule_b.id}",
               params: { rule_id: rule_a.id, satisfied_by_rule_id: rule_b.id }
      end.not_to change(RuleSatisfaction, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(rule_a.reload.satisfied_by).to include(rule_b)
    end
  end
end
