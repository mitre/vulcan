# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Project do
  let(:project) { create(:project) }
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:user3) { create(:user) }

  before do
    # Add user1 to project
    create(:membership, :admin, membership: project, user: user1)
  end

  describe 'available_members security' do
    it 'does not expose all registered users emails' do
      # This prevents CVE-style email enumeration
      # available_members should NOT return all non-member users
      available = project.available_members

      # Should return empty array to prevent enumeration
      expect(available).to be_empty
    end

    it 'does not leak user2 email who is not a project member' do
      available_emails = project.available_members.map(&:email)

      # user2 and user3 are not project members
      # Their emails should NOT be exposed
      expect(available_emails).not_to include(user2.email)
      expect(available_emails).not_to include(user3.email)
    end

    it 'does not expose email count that could indicate total user base' do
      # Even the count of available members is sensitive
      # as it reveals total registered users
      expect(project.available_members.count).to eq(0)
    end
  end
end
