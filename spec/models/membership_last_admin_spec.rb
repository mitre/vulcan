# frozen_string_literal: true

require 'rails_helper'

# Project admin continuity (GitLab/GitHub last-owner pattern):
# a project must never drop to zero admin memberships through the
# membership API — transfer ownership first. Component memberships are
# exempt: project admins govern components via effective_permissions,
# so a component with no admin membership is not orphaned. Cascades
# (project deletion, user deletion) are exempt via destroyed_by_association;
# the user-deletion path gets its own guard in the follow-up card.
RSpec.describe Membership do
  let_it_be(:anchor_admin) { create(:user, admin: true) }

  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let!(:admin_membership) { create(:membership, user: user, membership: project, role: 'admin') }

  describe 'destroying the last project admin membership' do
    it 'is prevented, keeps the membership, and names the project' do
      expect(admin_membership.destroy).to be(false)
      expect(admin_membership.errors[:base].join)
        .to include("Cannot remove the last admin of project '#{project.name}'")
      expect(admin_membership.errors[:base].join).to include('Transfer the admin role')
      expect(described_class.exists?(admin_membership.id)).to be(true)
    end

    it 'raises on destroy!' do
      expect { admin_membership.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    end
  end

  describe 'destroying an admin membership when another project admin exists' do
    it 'succeeds' do
      create(:membership, user: create(:user), membership: project, role: 'admin')

      expect(admin_membership.destroy).to be_truthy
      expect(described_class.exists?(admin_membership.id)).to be(false)
    end
  end

  describe 'downgrading the last project admin' do
    it 'is invalid and leaves the stored role unchanged' do
      expect(admin_membership.update(role: 'author')).to be(false)
      expect(admin_membership.errors[:role].join)
        .to include("is the last admin of project '#{project.name}'")
      expect(admin_membership.reload.role).to eq('admin')
    end
  end

  describe 'downgrading an admin when another project admin exists' do
    it 'succeeds' do
      create(:membership, user: create(:user), membership: project, role: 'admin')

      expect(admin_membership.update(role: 'reviewer')).to be(true)
      expect(admin_membership.reload.role).to eq('reviewer')
    end
  end

  describe 'component memberships' do
    let(:component) { create(:component, project: project) }
    let(:component_admin) do
      create(:membership, user: create(:user), membership: component, role: 'admin')
    end

    it 'can be destroyed even as the only component admin (project admins govern components)' do
      expect(component_admin.destroy).to be_truthy
      expect(described_class.exists?(component_admin.id)).to be(false)
    end

    it 'can be downgraded even as the only component admin' do
      expect(component_admin.update(role: 'author')).to be(true)
      expect(component_admin.reload.role).to eq('author')
    end
  end

  describe 'cascade escapes' do
    it 'allows destroying the project itself with a sole admin membership' do
      membership_id = admin_membership.id
      expect(project.destroy).to be_truthy
      expect(described_class.exists?(membership_id)).to be(false)
    end

    it 'allows destroying the user (membership cascade) — user-level guard is the follow-up card' do
      membership_id = admin_membership.id
      expect(user.destroy).to be_truthy
      expect(described_class.exists?(membership_id)).to be(false)
    end
  end
end
