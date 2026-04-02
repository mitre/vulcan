# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rules' do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project) }
  let(:rule) { component.rules.first }

  before do
    Rails.application.reload_routes!
    sign_in user
    Membership.create!(user: user, membership: project, role: 'admin')
  end

  # ==========================================================================
  # DATA FLOW CONTRACT: EDIT page must receive component data with
  # histories, reviews, and metadata for sidebars to display correctly
  #
  # REQUIREMENT: When user visits the EDIT page, the component data passed
  # to the Vue app must include histories, reviews, and metadata so the
  # sidebar panels can display this information.
  # ==========================================================================
  describe 'GET /components/:component_id/edit (rules#index)' do
    context 'component data contract' do
      it 'includes histories in component JSON for sidebar display' do
        # Create a review which generates history via audited gem
        Review.create!(
          user: user,
          rule: rule,
          action: 'comment',
          comment: 'Test review comment for history'
        )

        get "/components/#{component.id}/edit"

        expect(response).to have_http_status(:success)
        # HAML embeds JSON in v-bind attribute - quotes are HTML-escaped as &quot;
        # Verify the histories key is present in the component JSON
        expect(response.body).to include('&quot;histories&quot;')
      end

      it 'includes reviews in component JSON for sidebar display' do
        # Create a review on a rule in this component
        Review.create!(
          user: user,
          rule: rule,
          action: 'comment',
          comment: 'Test sidebar review'
        )

        get "/components/#{component.id}/edit"

        expect(response).to have_http_status(:success)
        # Verify the reviews key is present in the component JSON
        expect(response.body).to include('&quot;reviews&quot;')
        # Verify the actual review content is included
        expect(response.body).to include('Test sidebar review')
      end

      it 'includes metadata in component JSON for sidebar display' do
        # Add metadata via component_metadata association (metadata is a delegate method)
        component.create_component_metadata!(data: { 'Environment' => 'Production', 'Team' => 'Security' })

        get "/components/#{component.id}/edit"

        expect(response).to have_http_status(:success)
        # Verify the metadata key is present in the component JSON
        expect(response.body).to include('&quot;metadata&quot;')
        # Verify the actual metadata values are included
        expect(response.body).to include('Production')
        expect(response.body).to include('Security')
      end

      it 'includes all_users in component JSON for UpdateComponentDetailsModal PoC dropdown' do
        # REQUIREMENT: UpdateComponentDetailsModal needs all_users for PoC selection dropdown
        get "/components/#{component.id}/edit"

        expect(response).to have_http_status(:success)
        # Verify the all_users key is present in the component JSON
        expect(response.body).to include('&quot;all_users&quot;')
      end

    end
  end

  describe 'inspec_control_body auto-population' do
    it 'seeds inspec_control_body with a stub describe block on rule creation' do
      rule = component.rules.first
      expect(rule.inspec_control_body).to be_present
      expect(rule.inspec_control_body).to include('describe file')
      expect(rule.inspec_control_body).to include('should be_directory')
    end
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
      it 'still works or shows a clear error' do
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

  describe 'DELETE /rules/:id' do
    context 'as project admin' do
      it 'soft-deletes the rule' do
        rule_id = rule.id
        delete "/rules/#{rule_id}"

        expect(response).to have_http_status(:success)
        expect(Rule.unscoped.find(rule_id).deleted_at).not_to be_nil
      end

      it 'soft-deletes a locked rule with warning' do
        rule.update_columns(locked: true)
        delete "/rules/#{rule.id}"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['toast']).to include('Warning')
        expect(json['toast']).to include('locked')
      end

      it 'soft-deletes a rule under review with warning' do
        rule.update_columns(review_requestor_id: user.id)
        delete "/rules/#{rule.id}"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['toast']).to include('Warning')
        expect(json['toast']).to include('under review')
      end

      it 'cleans up associated records' do
        Review.create!(user: user, rule: rule, action: 'comment', comment: 'test')
        expect(rule.reviews.count).to eq(1)

        delete "/rules/#{rule.id}"

        expect(response).to have_http_status(:success)
        expect(Review.where(rule_id: rule.id).count).to eq(0)
      end

      it 'excludes deleted rule from default scope' do
        rule_id = rule.id
        delete "/rules/#{rule_id}"

        expect(Rule.find_by(id: rule_id)).to be_nil
        expect(Rule.unscoped.find(rule_id)).not_to be_nil
      end
    end

    context 'as non-admin' do
      let_it_be(:viewer) { create(:user) }

      before do
        Membership.where(user: user, membership: project).destroy_all
        sign_in viewer
        Membership.create!(user: viewer, membership: project, role: 'viewer')
      end

      it 'rejects deletion' do
        delete "/rules/#{rule.id}"

        expect(response).to have_http_status(:forbidden).or have_http_status(:redirect)
      end
    end
  end
end
