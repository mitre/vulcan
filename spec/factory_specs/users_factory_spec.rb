# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: User factory must support role traits that mirror db/seeds.rb so
# tests can compose the same shape as the seed file (admin / viewer / author /
# reviewer users with project memberships). Keeps seed and test data consistent.
#
# Trait contract:
# - :admin sets the Vulcan-level admin flag (User#admin = true). Standalone.
# - :viewer / :author / :reviewer are project-role labels that compose with
#   :with_membership. Alone they set a transient role; they do not create a
#   Membership themselves.
# - :with_membership creates a Membership on a project. Default role: viewer.
#   Default project: a fresh create(:project) when none is given.

RSpec.describe 'User factory traits' do
  describe ':admin trait' do
    it 'sets the Vulcan admin flag' do
      expect(build(:user, :admin).admin).to be true
    end

    it 'leaves admin false on a plain user' do
      expect(build(:user).admin).to be_falsey
    end
  end

  describe ':with_membership trait' do
    let(:project) { create(:project) }

    it 'creates a Membership on the given project' do
      user = create(:user, :with_membership, project: project)
      expect(user.memberships.where(membership: project)).to exist
    end

    it 'defaults the role to viewer' do
      user = create(:user, :with_membership, project: project)
      expect(user.memberships.find_by(membership: project).role).to eq('viewer')
    end

    it 'creates a project automatically when none is given' do
      user = create(:user, :with_membership)
      expect(user.memberships.count).to eq(1)
      expect(user.memberships.first.membership).to be_a(Project)
    end
  end

  describe 'role-tier traits composed with :with_membership' do
    let(:project) { create(:project) }

    it ':viewer + :with_membership creates a viewer membership' do
      user = create(:user, :viewer, :with_membership, project: project)
      expect(user.memberships.find_by(membership: project).role).to eq('viewer')
    end

    it ':author + :with_membership creates an author membership' do
      user = create(:user, :author, :with_membership, project: project)
      expect(user.memberships.find_by(membership: project).role).to eq('author')
    end

    it ':reviewer + :with_membership creates a reviewer membership' do
      user = create(:user, :reviewer, :with_membership, project: project)
      expect(user.memberships.find_by(membership: project).role).to eq('reviewer')
    end
  end
end
