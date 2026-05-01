# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Review and Membership Blueprints' do
  let_it_be(:user) { create(:user, name: 'Test Reviewer', email: 'reviewer@test.com') }

  let(:reviewer_name) { user.name }
  let(:reviewer_email) { user.email }

  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { SecurityRequirementsGuide.first || create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg) }
  let_it_be(:rule) { component.rules.first }

  describe ReviewBlueprint do
    # `refind: true` so each example gets a fresh AR instance — earlier
    # examples in this block call `update_columns` to set triage/adjudicator
    # attribution. Savepoint rolls the DB back, but the cached in-memory
    # object would still carry mutated attributes without refind.
    let_it_be(:review, refind: true) do
      Review.create!(user: user, rule: rule, action: 'comment', comment: 'Looks good')
    end

    it 'includes id, action, comment, created_at, and name' do
      json = ReviewBlueprint.render_as_hash(review)

      expect(json[:id]).to eq(review.id)
      expect(json[:action]).to eq('comment')
      expect(json[:comment]).to eq('Looks good')
      expect(json[:created_at]).to be_present
      expect(json[:name]).to eq(reviewer_name)
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

    describe 'PR-717 .8 attribution display fields' do
      let_it_be(:triager) { create(:user, name: 'Tri Ager', email: 'triager@test.com') }
      let_it_be(:adjudicator) { create(:user, name: 'Adj Udic', email: 'adj@test.com') }

      it 'exposes triager_display_name and triager_imported when FK resolved' do
        review.update_columns(
          triage_status: 'concur',
          triage_set_by_id: triager.id,
          triage_set_at: Time.current
        )
        json = ReviewBlueprint.render_as_hash(review.reload)
        expect(json[:triager_display_name]).to eq('Tri Ager')
        expect(json[:triager_imported]).to be(false)
      end

      it 'falls back to imported attribution and flags imported=true' do
        review.update_columns(
          triage_status: 'concur',
          triage_set_at: Time.current,
          triage_set_by_imported_name: 'Old Triager',
          triage_set_by_imported_email: 'old@former.example'
        )
        json = ReviewBlueprint.render_as_hash(review.reload)
        expect(json[:triager_display_name]).to eq('Old Triager')
        expect(json[:triager_imported]).to be(true)
      end

      it 'exposes adjudicator_display_name and adjudicator_imported when FK resolved' do
        review.update_columns(
          adjudicated_by_id: adjudicator.id,
          adjudicated_at: Time.current
        )
        json = ReviewBlueprint.render_as_hash(review.reload)
        expect(json[:adjudicator_display_name]).to eq('Adj Udic')
        expect(json[:adjudicator_imported]).to be(false)
      end

      it 'falls back to imported_email when imported_name is blank' do
        review.update_columns(
          adjudicated_at: Time.current,
          adjudicated_by_imported_email: 'orig-adj@former.example'
        )
        json = ReviewBlueprint.render_as_hash(review.reload)
        expect(json[:adjudicator_display_name]).to eq('orig-adj@former.example')
        expect(json[:adjudicator_imported]).to be(true)
      end

      it 'returns nil display_name and false imported when nothing is set' do
        json = ReviewBlueprint.render_as_hash(review)
        expect(json[:triager_display_name]).to be_nil
        expect(json[:triager_imported]).to be(false)
        expect(json[:adjudicator_display_name]).to be_nil
        expect(json[:adjudicator_imported]).to be(false)
      end

      it 'exposes triage_set_at, adjudicated_at, and triage_status for the modal' do
        time = Time.current
        review.update_columns(triage_status: 'concur', triage_set_at: time, adjudicated_at: time)
        json = ReviewBlueprint.render_as_hash(review.reload)
        expect(json[:triage_status]).to eq('concur')
        expect(json[:triage_set_at]).to be_present
        expect(json[:adjudicated_at]).to be_present
      end
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
      expect(json[:name]).to eq(reviewer_name)
      expect(json[:email]).to eq(reviewer_email)
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
      expect(json[:name]).to eq(reviewer_name)
      expect(json[:email]).to eq(reviewer_email)
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
