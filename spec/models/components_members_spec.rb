# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component do
  include_context 'components model base setup'

  # Users with different membership scopes
  let_it_be(:member_user) { create(:user, name: 'Alice Member', email: 'alice@example.com') }
  let_it_be(:project_user) { create(:user, name: 'Bob Project', email: 'bob@example.com') }
  let_it_be(:outside_user) { create(:user, name: 'Carol Outside', email: 'carol@example.com') }
  let_it_be(:dual_user) { create(:user, name: 'Dana Dual', email: 'dana@example.com') }
  let_it_be(:project_admin) { create(:user, name: 'Eve Admin', email: 'eve@example.com') }

  before_all do
    Membership.create!(user: member_user, membership: components_component, role: 'author')
    Membership.create!(user: project_user, membership: components_project, role: 'reviewer')
    Membership.create!(user: dual_user, membership: components_component, role: 'viewer')
    Membership.create!(user: dual_user, membership: components_project, role: 'reviewer')
    Membership.create!(user: project_admin, membership: components_project, role: 'admin')
  end

  describe '#search_available_members' do
    it 'returns users matching name substring' do
      results = components_component.search_available_members('Carol')
      expect(results.pluck(:name)).to contain_exactly('Carol Outside')
    end

    it 'returns users matching email substring' do
      results = components_component.search_available_members('carol@')
      expect(results.pluck(:email)).to contain_exactly('carol@example.com')
    end

    it 'escapes SQL wildcard % character' do
      results = components_component.search_available_members('%')
      expect(results).to be_empty
    end

    it 'escapes SQL wildcard _ character' do
      results = components_component.search_available_members('_')
      expect(results).to be_empty
    end

    it 'escapes SQL backslash character' do
      results = components_component.search_available_members('\\')
      expect(results).to be_empty
    end

    it 'respects the limit parameter' do
      results = components_component.search_available_members('example.com', limit: 1)
      expect(results.size).to eq(1)
    end

    it 'excludes users already on the component' do
      results = components_component.search_available_members('Alice')
      expect(results.pluck(:name)).not_to include('Alice Member')
    end

    it 'excludes project admins' do
      results = components_component.search_available_members('Eve')
      expect(results.pluck(:name)).not_to include('Eve Admin')
    end
  end

  describe '#search_members' do
    it 'returns direct component members matching query' do
      results = components_component.search_members('Alice')
      expect(results.pluck(:name)).to contain_exactly('Alice Member')
    end

    it 'returns project-level members (inherited)' do
      results = components_component.search_members('Bob')
      expect(results.pluck(:name)).to contain_exactly('Bob Project')
    end

    it 'escapes SQL wildcard % character' do
      results = components_component.search_members('%')
      expect(results).to be_empty
    end

    it 'escapes SQL wildcard _ character' do
      results = components_component.search_members('_')
      expect(results).to be_empty
    end

    it 'respects the limit parameter' do
      results = components_component.search_members('example.com', limit: 1)
      expect(results.size).to eq(1)
    end
  end

  describe '#all_users' do
    it 'returns combined component and project users' do
      result_names = components_component.all_users.map(&:name)
      expect(result_names).to include('Alice Member', 'Bob Project', 'Dana Dual', 'Eve Admin')
    end

    it 'deduplicates users who appear in both' do
      all = components_component.all_users
      dana_count = all.count { |u| u.id == dual_user.id }
      expect(dana_count).to eq(1)
    end
  end

  describe '#admins' do
    it 'returns project-level admins when no component admin exists' do
      admin_emails = components_component.admins.map(&:email)
      expect(admin_emails).to include('eve@example.com')
    end

    context 'with a component-level admin' do
      let_it_be(:comp_admin) { create(:user, name: 'Frank CompAdmin', email: 'frank@example.com') }

      before_all do
        Membership.create!(user: comp_admin, membership: components_component, role: 'admin')
      end

      it 'returns the component-level admin' do
        admin_records = components_component.admins
        expect(admin_records.map(&:email)).to include('frank@example.com')
      end

      it 'includes both component and project admins' do
        admin_records = components_component.admins
        types = admin_records.map(&:membership_type)
        expect(types).to include('Component', 'Project')
      end
    end
  end

  describe '#inherited_memberships' do
    it 'excludes users who already have component-level membership' do
      inherited = components_component.inherited_memberships
      inherited_user_ids = inherited.pluck(:user_id)
      component_user_ids = components_component.memberships.pluck(:user_id)
      expect(inherited_user_ids & component_user_ids).to be_empty
    end

    it 'includes project-level members who are not on the component' do
      project_only = create(:user, name: 'Project Only')
      Membership.create!(user: project_only, membership: components_project, role: 'viewer')

      inherited = components_component.inherited_memberships
      expect(inherited.pluck(:user_id)).to include(project_only.id)
    end
  end
end
