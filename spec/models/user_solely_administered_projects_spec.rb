# frozen_string_literal: true

require 'rails_helper'

# Shared source of truth for the user-deletion continuity guard: the
# projects that would be orphaned if this user were deleted (user holds
# the ONLY admin membership). Component memberships never count —
# project admins govern components via effective_permissions.
RSpec.describe User do
  let_it_be(:anchor_admin) { create(:user, admin: true) }

  let(:user) { create(:user) }

  describe '#solely_administered_projects' do
    it 'returns projects where the user is the only admin member' do
      solo = create(:project)
      create(:membership, user: user, membership: solo, role: 'admin')

      expect(user.solely_administered_projects).to contain_exactly(solo)
    end

    it 'excludes projects that have another admin' do
      shared = create(:project)
      create(:membership, user: user, membership: shared, role: 'admin')
      create(:membership, user: create(:user), membership: shared, role: 'admin')

      expect(user.solely_administered_projects).to be_empty
    end

    it 'excludes projects where the user is a non-admin member' do
      viewed = create(:project)
      create(:membership, user: user, membership: viewed, role: 'viewer')

      expect(user.solely_administered_projects).to be_empty
    end

    it 'ignores sole COMPONENT admin memberships' do
      project = create(:project)
      component = create(:component, project: project)
      create(:membership, user: user, membership: component, role: 'admin')

      expect(user.solely_administered_projects).to be_empty
    end

    it 'returns multiple orphan-risk projects sorted by name' do
      b = create(:project, name: 'Bravo Project')
      a = create(:project, name: 'Alpha Project')
      create(:membership, user: user, membership: b, role: 'admin')
      create(:membership, user: user, membership: a, role: 'admin')

      expect(user.solely_administered_projects.map(&:name))
        .to eq(['Alpha Project', 'Bravo Project'])
    end
  end

  describe '#sole_admin_deletion_block_message' do
    it 'is nil when the user solely administers nothing' do
      expect(user.sole_admin_deletion_block_message).to be_nil
    end

    it 'names the blocking projects and says to transfer ownership' do
      project = create(:project, name: 'Photon OS 5')
      create(:membership, user: user, membership: project, role: 'admin')

      message = user.sole_admin_deletion_block_message
      expect(message).to include("the only admin of: 'Photon OS 5'")
      expect(message).to include('Transfer the admin role')
    end

    it 'caps the list at five project names with an overflow count' do
      7.times do |i|
        p = create(:project, name: format('Proj %02d', i))
        create(:membership, user: user, membership: p, role: 'admin')
      end

      message = user.sole_admin_deletion_block_message
      expect(message).to include("'Proj 00'")
      expect(message).to include("'Proj 04'")
      expect(message).not_to include("'Proj 05'")
      expect(message).to include('and 2 more')
    end
  end
end
