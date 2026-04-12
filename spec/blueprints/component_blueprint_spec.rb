# frozen_string_literal: true

require 'rails_helper'

##
# ComponentBlueprint Tests
#
# REQUIREMENT: The :editor view must produce output field-compatible with
# the current `to_json(methods: %i[histories memberships metadata
# inherited_memberships rules reviews])`.
#
# SECURITY: available_members and all_users were removed from the payload
# to prevent information disclosure of the full user directory. These are
# now fetched on demand via /api/users/search (and ?scope=members for the
# PoC dropdown). Tests below assert these fields are NOT present.
#
RSpec.describe 'ComponentBlueprint' do
  let_it_be(:admin_user) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { SecurityRequirementsGuide.first || create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg) }
  let_it_be(:membership) do
    Membership.find_or_create_by!(user: admin_user, membership: component, role: 'admin')
  end

  describe ':index view' do
    let(:json) { ComponentBlueprint.render_as_hash(component, view: :index) }

    it 'includes listing fields' do
      %i[id name prefix version release based_on_title based_on_version].each do |f|
        expect(json).to have_key(f), "Missing :index field: #{f}"
      end
    end

    it 'includes severity_counts' do
      expect(json).to have_key(:severity_counts)
    end

    it 'excludes heavy fields' do
      expect(json).not_to have_key(:rules)
      expect(json).not_to have_key(:histories)
      expect(json).not_to have_key(:available_members)
    end
  end

  describe ':show view (non-member, released component)' do
    let(:json) { ComponentBlueprint.render_as_hash(component, view: :show) }

    it 'includes rules and reviews' do
      expect(json).to have_key(:rules)
      expect(json).to have_key(:reviews)
      expect(json[:rules]).to be_an(Array)
    end

    it 'excludes editor-only fields' do
      expect(json).not_to have_key(:available_members)
      expect(json).not_to have_key(:all_users)
      expect(json).not_to have_key(:inherited_memberships)
    end
  end

  describe ':editor view (project member)' do
    let(:json) { ComponentBlueprint.render_as_hash(component, view: :editor) }

    it 'includes all DB columns needed by Vue' do
      %i[id name prefix version release title description
         admin_name admin_email released advanced_fields
         project_id component_id security_requirements_guide_id
         memberships_count rules_count updated_at].each do |f|
        expect(json).to have_key(f), "Missing :editor field: #{f}"
      end
    end

    it 'includes computed fields' do
      expect(json).to have_key(:based_on_title)
      expect(json).to have_key(:based_on_version)
      expect(json).to have_key(:releasable)
      expect(json).to have_key(:severity_counts)
      expect(json).to have_key(:status_counts)
    end

    it 'includes all method-derived data' do
      expect(json).to have_key(:rules)
      expect(json).to have_key(:reviews)
      expect(json).to have_key(:histories)
      expect(json).to have_key(:memberships)
      expect(json).to have_key(:metadata)
      expect(json).to have_key(:inherited_memberships)
      expect(json).to have_key(:additional_questions)
    end

    it 'does NOT include dead admins field' do
      # Per Vue analysis: no component page Vue consumer reads component.admins
      expect(json).not_to have_key(:admins)
    end

    it 'does NOT include available_members or all_users (information disclosure regression guard)' do
      # SECURITY: pre-loading the full user directory into the payload was an
      # information disclosure issue. The Add Member dropdown and PoC dropdown
      # now fetch via /api/users/search and /api/users/search?scope=members.
      expect(json).not_to have_key(:available_members)
      expect(json).not_to have_key(:all_users)
    end

    it 'rules are serialized via RuleBlueprint :editor' do
      if json[:rules].any?
        rule_json = json[:rules].first
        # RuleBlueprint :editor includes these
        expect(rule_json).to have_key(:srg_rule_attributes)
        expect(rule_json).to have_key(:reviews)
        expect(rule_json).to have_key(:srg_info)
      end
    end

    it 'memberships include name and email' do
      if json[:memberships].any?
        m = json[:memberships].first
        expect(m).to have_key(:name)
        expect(m).to have_key(:email)
        expect(m).to have_key(:role)
      end
    end
  end
end
