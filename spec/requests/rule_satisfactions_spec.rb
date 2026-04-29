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

      expect(response).to have_http_status(:unprocessable_entity)
      expect(rule_a.reload.satisfied_by).not_to include(rule_b)
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

      expect(response).to have_http_status(:unprocessable_entity)
      expect(rule_a.reload.satisfied_by).to include(rule_b)
    end
  end
end
