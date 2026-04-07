# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Review and Membership Blueprints' do
  let_it_be(:user) { create(:user, name: 'Test Reviewer', email: 'reviewer@test.com') }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { SecurityRequirementsGuide.first || create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg) }
  let_it_be(:rule) { component.rules.first }

  describe ReviewBlueprint do
    let_it_be(:review) { Review.create!(user: user, rule: rule, action: 'comment', comment: 'Looks good') }

    it 'includes id, action, comment, created_at, and name' do
      json = ReviewBlueprint.render_as_hash(review)

      expect(json[:id]).to eq(review.id)
      expect(json[:action]).to eq('comment')
      expect(json[:comment]).to eq('Looks good')
      expect(json[:created_at]).to be_present
      expect(json[:name]).to eq('Test Reviewer')
    end

    it 'excludes user_id, rule_id, updated_at (matches Rule#as_json strip pattern)' do
      json = ReviewBlueprint.render_as_hash(review)

      expect(json).not_to have_key(:user_id)
      expect(json).not_to have_key(:rule_id)
      expect(json).not_to have_key(:updated_at)
    end

    it 'handles nil user gracefully' do
      orphan_review = Review.new(action: 'comment', comment: 'test')
      json = ReviewBlueprint.render_as_hash(orphan_review)

      expect(json[:name]).to be_nil
    end
  end

  describe MembershipBlueprint do
    let_it_be(:membership) do
      Membership.find_or_create_by!(user: user, membership: component, role: 'author')
    end

    it 'includes id, user_id, role, name, email, membership_type' do
      json = MembershipBlueprint.render_as_hash(membership)

      expect(json[:id]).to eq(membership.id)
      expect(json[:user_id]).to eq(user.id)
      expect(json[:role]).to eq('author')
      expect(json[:name]).to eq('Test Reviewer')
      expect(json[:email]).to eq('reviewer@test.com')
      expect(json[:membership_type]).to eq('Component')
    end

    it 'excludes timestamps' do
      json = MembershipBlueprint.render_as_hash(membership)

      expect(json).not_to have_key(:created_at)
      expect(json).not_to have_key(:updated_at)
    end
  end

  describe UserBlueprint do
    it 'includes only id, name, email' do
      json = UserBlueprint.render_as_hash(user)

      expect(json.keys.sort).to eq(%i[email id name])
      expect(json[:id]).to eq(user.id)
      expect(json[:name]).to eq('Test Reviewer')
      expect(json[:email]).to eq('reviewer@test.com')
    end

    it 'does NOT include sensitive fields' do
      json = UserBlueprint.render_as_hash(user)

      expect(json).not_to have_key(:encrypted_password)
      expect(json).not_to have_key(:admin)
      expect(json).not_to have_key(:provider)
      expect(json).not_to have_key(:uid)
      expect(json).not_to have_key(:reset_password_token)
    end
  end
end
