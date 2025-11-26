# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rules', type: :request do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:component) { create(:component, project: project) }
  let(:rule) { component.rules.first }

  before do
    Rails.application.reload_routes!
    sign_in user
    create(:membership, :admin, membership: project, user: user)
  end

  describe 'PUT /rules/:id' do
    context 'when updating nested attributes' do
      it 'updates check content (check text)' do
        original_content = rule.checks.first.content
        new_content = 'Updated check text content'

        put "/rules/#{rule.id}", params: {
          rule: {
            checks_attributes: [
              {
                id: rule.checks.first.id,
                content: new_content
              }
            ]
          }
        }

        expect(response).to have_http_status(:success)
        expect(rule.checks.first.reload.content).to eq(new_content)
        expect(rule.checks.first.content).not_to eq(original_content)
      end

      it 'updates fixtext (fix text)' do
        original_fixtext = rule.fixtext
        new_fixtext = 'Updated fix text content'

        put "/rules/#{rule.id}", params: {
          rule: {
            fixtext: new_fixtext
          }
        }

        expect(response).to have_http_status(:success)
        expect(rule.reload.fixtext).to eq(new_fixtext)
        expect(rule.fixtext).not_to eq(original_fixtext)
      end

      it 'updates disa_rule_description vuln_discussion (vuln description)' do
        original_vuln_discussion = rule.disa_rule_descriptions.first.vuln_discussion
        new_vuln_discussion = 'Updated vulnerability discussion content'

        put "/rules/#{rule.id}", params: {
          rule: {
            disa_rule_descriptions_attributes: [
              {
                id: rule.disa_rule_descriptions.first.id,
                vuln_discussion: new_vuln_discussion
              }
            ]
          }
        }

        expect(response).to have_http_status(:success)
        expect(rule.disa_rule_descriptions.first.reload.vuln_discussion).to eq(new_vuln_discussion)
        expect(rule.disa_rule_descriptions.first.vuln_discussion).not_to eq(original_vuln_discussion)
      end

      it 'updates status' do
        original_status = rule.status
        new_status = 'Applicable - Inherently Meets'

        put "/rules/#{rule.id}", params: {
          rule: {
            status: new_status
          }
        }

        expect(response).to have_http_status(:success)
        expect(rule.reload.status).to eq(new_status)
        expect(rule.status).not_to eq(original_status)
      end

      it 'updates multiple fields at once (simulating real frontend behavior)' do
        new_title = 'Updated Title'
        new_fixtext = 'Updated Fix Text'
        new_check_content = 'Updated Check Content'
        new_vuln_discussion = 'Updated Vuln Discussion'

        put "/rules/#{rule.id}", params: {
          rule: {
            title: new_title,
            fixtext: new_fixtext,
            audit_comment: 'Testing multi-field update',
            checks_attributes: [
              {
                id: rule.checks.first.id,
                system: rule.checks.first.system,
                content_ref_name: rule.checks.first.content_ref_name,
                content_ref_href: rule.checks.first.content_ref_href,
                content: new_check_content,
                _destroy: false
              }
            ],
            disa_rule_descriptions_attributes: [
              {
                id: rule.disa_rule_descriptions.first.id,
                vuln_discussion: new_vuln_discussion,
                _destroy: false
              }
            ]
          }
        }

        expect(response).to have_http_status(:success)

        rule.reload
        expect(rule.title).to eq(new_title)
        expect(rule.fixtext).to eq(new_fixtext)
        expect(rule.checks.first.content).to eq(new_check_content)
        expect(rule.disa_rule_descriptions.first.vuln_discussion).to eq(new_vuln_discussion)
      end
    end

    context 'when updating without id in nested attributes' do
      it 'should still work or show clear error' do
        new_content = 'Updated without id'

        put "/rules/#{rule.id}", params: {
          rule: {
            checks_attributes: [
              {
                # Deliberately omitting id to test behavior
                content: new_content
              }
            ]
          }
        }

        # This might create a new check instead of updating
        # Let's verify the behavior
        rule.reload
        # Either the existing check is updated OR a new one is created
        expect(rule.checks.pluck(:content)).to include(new_content)
      end
    end
  end
end
