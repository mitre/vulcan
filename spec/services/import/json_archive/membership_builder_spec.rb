# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: MembershipBuilder restores project memberships from backup
# JSON. It resolves users by email (fallback: name), skips unknown users
# and duplicate memberships with warnings.
# ==========================================================================
RSpec.describe Import::JsonArchive::MembershipBuilder do
  let(:project) { create(:project) }
  let(:result) { Import::Result.new }
  let(:user_a) { create(:user, email: 'alice@example.com', name: 'Alice') }
  let(:user_b) { create(:user, email: 'bob@example.com', name: 'Bob') }

  describe '#build_all' do
    context 'with valid membership data' do
      let(:memberships_data) do
        [
          { 'email' => user_a.email, 'name' => user_a.name, 'role' => 'admin' },
          { 'email' => user_b.email, 'name' => user_b.name, 'role' => 'viewer' }
        ]
      end

      it 'creates memberships for known users' do
        count = described_class.new(memberships_data, project, result).build_all
        expect(count).to eq(2)
        expect(project.memberships.where(membership_type: 'Project').count).to eq(2)
      end

      it 'preserves roles from archive' do
        described_class.new(memberships_data, project, result).build_all
        expect(Membership.find_by(user: user_a, membership: project).role).to eq('admin')
        expect(Membership.find_by(user: user_b, membership: project).role).to eq('viewer')
      end
    end

    context 'with unknown user' do
      let(:memberships_data) do
        [{ 'email' => 'ghost@example.com', 'name' => 'Ghost', 'role' => 'viewer' }]
      end

      it 'skips unknown user and adds warning' do
        count = described_class.new(memberships_data, project, result).build_all
        expect(count).to eq(0)
        expect(result.warnings).to include(a_string_matching(/ghost@example\.com.*not found/))
      end
    end

    context 'with duplicate membership' do
      before do
        Membership.create!(user: user_a, membership: project, role: 'admin')
      end

      let(:memberships_data) do
        [{ 'email' => user_a.email, 'name' => user_a.name, 'role' => 'viewer' }]
      end

      it 'skips duplicate and adds warning' do
        count = described_class.new(memberships_data, project, result).build_all
        expect(count).to eq(0)
        expect(result.warnings).to include(a_string_matching(/already a member/))
      end
    end

    context 'with name-only resolution' do
      let(:memberships_data) do
        [{ 'name' => user_a.name, 'role' => 'author' }]
      end

      it 'resolves user by name when email is absent' do
        count = described_class.new(memberships_data, project, result).build_all
        expect(count).to eq(1)
        expect(Membership.find_by(user: user_a, membership: project)).to be_present
      end
    end

    context 'with nil memberships_data' do
      it 'handles nil gracefully' do
        count = described_class.new(nil, project, result).build_all
        expect(count).to eq(0)
      end
    end

    context 'with missing role' do
      let(:memberships_data) do
        [{ 'email' => user_a.email, 'name' => user_a.name }]
      end

      it 'defaults to viewer role' do
        described_class.new(memberships_data, project, result).build_all
        expect(Membership.find_by(user: user_a, membership: project).role).to eq('viewer')
      end
    end
  end
end
