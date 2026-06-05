# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Components' do
  include_context 'components request base setup'

  # ==========================================================================
  # REQUIREMENT: UpdateComponentDetailsModal must be able to update basic
  # component fields (name, description, version, etc.) WITHOUT sending
  # advanced_fields. The before_action filter should not require advanced_fields.
  # ==========================================================================
  describe 'PUT /components/:id' do
    context 'when updating basic fields without advanced_fields' do
      it 'updates name successfully' do
        put "/components/#{component.id}", params: {
          component: {
            name: 'Updated Component Name'
          }
        }

        expect(response).to have_http_status(:success)
        expect(component.reload.name).to eq('Updated Component Name')
      end

      it 'updates description successfully' do
        put "/components/#{component.id}", params: {
          component: {
            description: 'Updated description text'
          }
        }

        expect(response).to have_http_status(:success)
        expect(component.reload.description).to eq('Updated description text')
      end

      it 'updates multiple basic fields at once' do
        put "/components/#{component.id}", params: {
          component: {
            name: 'New Name',
            version: '2',
            release: '1',
            title: 'New Title',
            description: 'New description'
          }
        }

        expect(response).to have_http_status(:success)
        component.reload
        expect(component.name).to eq('New Name')
        expect(component.version.to_s).to eq('2')
        expect(component.release.to_s).to eq('1')
        expect(component.title).to eq('New Title')
        expect(component.description).to eq('New description')
      end
    end

    context 'when updating advanced_fields' do
      it 'allows admin to update advanced_fields' do
        # Admin membership already set up in before block
        put "/components/#{component.id}", params: {
          component: {
            advanced_fields: true
          }
        }

        expect(response).to have_http_status(:success)
        expect(component.reload.advanced_fields).to be(true)
      end
    end

    # The controller must permit the lifecycle params or strong params
    # filters them out and the model never sees them.
    context 'when updating the comment-phase fieldset' do
      it 'permits comment_phase, closed_reason, and date params' do
        put "/components/#{component.id}", params: {
          component: {
            comment_phase: 'closed',
            closed_reason: 'adjudicating',
            comment_period_starts_at: '2026-04-29',
            comment_period_ends_at: '2026-05-14'
          }
        }

        expect(response).to have_http_status(:success)
        component.reload
        expect(component.comment_phase).to eq('closed')
        expect(component.closed_reason).to eq('adjudicating')
        expect(component.comment_period_starts_at).not_to be_nil
        expect(component.comment_period_ends_at).not_to be_nil
      end

      it 'rejects invalid comment_phase via the model validator' do
        put "/components/#{component.id}", params: {
          component: { comment_phase: 'not-a-real-phase' }
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(component.reload.comment_phase).not_to eq('not-a-real-phase')
      end
    end
  end
end
