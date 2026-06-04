# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Membership do
  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg) }
  let_it_be(:user) { create(:user) }

  describe 'remove_equal_or_lesser_component_permissions' do
    it 'removes component-level memberships when project membership is created at equal or higher role' do
      # Create a component-level viewer membership
      Membership.create!(user: user, membership: component, role: 'viewer')
      expect(Membership.where(user: user, membership_type: 'Component').count).to eq(1)

      # Create a project-level author membership (higher than viewer)
      Membership.create!(user: user, membership: project, role: 'author')

      # The component-level viewer membership should be removed
      expect(Membership.where(user: user, membership_type: 'Component').count).to eq(0)
    end

    it 'does not remove component memberships with higher roles than the new project membership' do
      # Create a component-level admin membership
      Membership.create!(user: user, membership: component, role: 'admin')

      # Create a project-level viewer membership (lower than admin)
      Membership.create!(user: user, membership: project, role: 'viewer')

      # The component-level admin membership should remain
      expect(Membership.where(user: user, membership_type: 'Component').count).to eq(1)
    end
  end

  describe 'update_admin_contact_info callback' do
    it 'updates component admin_name and admin_email when admin membership is created' do
      Membership.create!(user: user, membership: component, role: 'admin')
      component.reload
      expect(component.admin_name).to eq(user.name)
      expect(component.admin_email).to eq(user.email)
    end

    it 'clears component admin info when the only admin membership is destroyed' do
      membership = Membership.create!(user: user, membership: component, role: 'admin')
      membership.destroy
      component.reload
      expect(component.admin_name).to be_nil
      expect(component.admin_email).to be_nil
    end
  end
end
