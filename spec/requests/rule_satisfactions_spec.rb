# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RuleSatisfactions' do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:component) { create(:component, project: project) }

  # Get two distinct rules from the component
  let(:parent_rule) { component.rules.first }
  let(:child_rule) { component.rules.second }

  before do
    Rails.application.reload_routes!
    sign_in user
    create(:membership, :admin, membership: project, user: user)
  end

  describe 'POST /rule_satisfactions' do
    context 'when user is authorized' do
      it 'creates a satisfaction relationship' do
        expect {
          post '/rule_satisfactions', params: {
            rule_id: parent_rule.id,
            satisfied_by_rule_id: child_rule.id
          }
        }.to change { parent_rule.satisfied_by.count }.by(1)

        expect(response).to have_http_status(:success)
        expect(parent_rule.reload.satisfied_by).to include(child_rule)
      end

      it 'returns a success toast message' do
        post '/rule_satisfactions', params: {
          rule_id: parent_rule.id,
          satisfied_by_rule_id: child_rule.id
        }

        json = response.parsed_body
        expect(json['toast']).to include('satisfied by')
      end

      it 'marks the child rule as merged (is_merged)' do
        post '/rule_satisfactions', params: {
          rule_id: parent_rule.id,
          satisfied_by_rule_id: child_rule.id
        }

        expect(child_rule.reload.satisfies).to include(parent_rule)
      end
    end

    context 'when parent rule is already a child of another rule' do
      before do
        # The controller checks if @rule.satisfies.empty? before adding
        # @rule is the parent_rule in params - if IT satisfies something,
        # it cannot also be a parent (would create circular dependency)
        third_rule = component.rules.third
        parent_rule.satisfies << third_rule # parent_rule is already satisfying third_rule
      end

      it 'returns an error if parent rule is already a child' do
        post '/rule_satisfactions', params: {
          rule_id: parent_rule.id,
          satisfied_by_rule_id: child_rule.id
        }

        # Controller returns error because @rule.satisfies is not empty
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when user is not authorized' do
      before do
        # Remove admin membership - user has no access
        user.memberships.destroy_all
      end

      it 'redirects to root (authorization failure)' do
        post '/rule_satisfactions', params: {
          rule_id: parent_rule.id,
          satisfied_by_rule_id: child_rule.id
        }

        # Rails authorization typically redirects rather than returning 403
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when not signed in' do
      before { sign_out user }

      it 'redirects to login' do
        post '/rule_satisfactions', params: {
          rule_id: parent_rule.id,
          satisfied_by_rule_id: child_rule.id
        }

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'DELETE /rule_satisfactions/:id' do
    before do
      # Create the satisfaction first
      parent_rule.satisfied_by << child_rule
    end

    context 'when user is authorized' do
      it 'removes the satisfaction relationship' do
        expect(parent_rule.satisfied_by).to include(child_rule)

        expect {
          delete '/rule_satisfactions/1', params: {
            rule_id: parent_rule.id,
            satisfied_by_rule_id: child_rule.id
          }
        }.to change { parent_rule.reload.satisfied_by.count }.by(-1)

        expect(response).to have_http_status(:success)
        expect(parent_rule.reload.satisfied_by).not_to include(child_rule)
      end

      it 'returns a success toast message' do
        delete '/rule_satisfactions/1', params: {
          rule_id: parent_rule.id,
          satisfied_by_rule_id: child_rule.id
        }

        json = response.parsed_body
        expect(json['toast']).to include('no longer marked as satisfied')
      end

      it 'unmarks the child rule (removes from satisfies)' do
        expect(child_rule.satisfies).to include(parent_rule)

        delete '/rule_satisfactions/1', params: {
          rule_id: parent_rule.id,
          satisfied_by_rule_id: child_rule.id
        }

        expect(child_rule.reload.satisfies).not_to include(parent_rule)
      end
    end

    context 'when user is not authorized' do
      before do
        user.memberships.destroy_all
      end

      it 'redirects to root (authorization failure)' do
        delete '/rule_satisfactions/1', params: {
          rule_id: parent_rule.id,
          satisfied_by_rule_id: child_rule.id
        }

        # Rails authorization typically redirects rather than returning 403
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when not signed in' do
      before { sign_out user }

      it 'redirects to login' do
        delete '/rule_satisfactions/1', params: {
          rule_id: parent_rule.id,
          satisfied_by_rule_id: child_rule.id
        }

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'undo flow (create after delete)' do
    before do
      # Create initial satisfaction
      parent_rule.satisfied_by << child_rule
    end

    it 'allows restoring a removed satisfaction' do
      # First, remove the satisfaction
      delete '/rule_satisfactions/1', params: {
        rule_id: parent_rule.id,
        satisfied_by_rule_id: child_rule.id
      }
      expect(response).to have_http_status(:success)
      expect(parent_rule.reload.satisfied_by).not_to include(child_rule)

      # Then, restore it (undo)
      post '/rule_satisfactions', params: {
        rule_id: parent_rule.id,
        satisfied_by_rule_id: child_rule.id
      }
      expect(response).to have_http_status(:success)
      expect(parent_rule.reload.satisfied_by).to include(child_rule)
    end

    it 'maintains data integrity through delete/restore cycle' do
      original_satisfied_by_count = parent_rule.satisfied_by.count

      # Delete
      delete '/rule_satisfactions/1', params: {
        rule_id: parent_rule.id,
        satisfied_by_rule_id: child_rule.id
      }

      # Restore
      post '/rule_satisfactions', params: {
        rule_id: parent_rule.id,
        satisfied_by_rule_id: child_rule.id
      }

      expect(parent_rule.reload.satisfied_by.count).to eq(original_satisfied_by_count)
    end
  end
end
