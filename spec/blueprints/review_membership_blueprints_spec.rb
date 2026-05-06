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

    it 'excludes user_id and updated_at (Rule#as_json strip pattern; rule_id added in .20)' do
      json = ReviewBlueprint.render_as_hash(review)

      expect(json).not_to have_key(:user_id)
      expect(json).not_to have_key(:updated_at)
    end

    it 'handles nil user gracefully' do
      orphan_review = Review.new(action: 'comment', comment: 'test')
      json = ReviewBlueprint.render_as_hash(orphan_review)

      expect(json[:name]).to be_nil
    end

    describe 'triager + adjudicator attribution fields' do
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

      # Task 33 PII guard: redact to role label when only imported_email
      # is populated (see ImportedAttribution).
      it 'redacts to "(imported adjudicator)" when only imported_email is populated' do
        review.update_columns(
          adjudicated_at: Time.current,
          adjudicated_by_imported_email: 'orig-adj@former.example'
        )
        json = ReviewBlueprint.render_as_hash(review.reload)
        expect(json[:adjudicator_display_name]).to eq('(imported adjudicator)')
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

    # commenter attribution
    # display fields. Mirrors triager_*/adjudicator_* in the same modal
    # (CommentTriageModal renders the commenter's display name + an
    # "imported" badge when the original User no longer exists locally).
    describe 'commenter attribution fields' do
      it 'exposes commenter_display_name and commenter_imported when User resolved' do
        json = ReviewBlueprint.render_as_hash(review)
        expect(json[:commenter_display_name]).to eq(reviewer_name)
        expect(json[:commenter_imported]).to be(false)
      end

      it 'falls back to commenter_imported_name when user_id is nil' do
        review.update_columns(user_id: nil,
                              commenter_imported_name: 'Imported Person',
                              commenter_imported_email: 'imp@old.example')
        json = ReviewBlueprint.render_as_hash(review.reload)
        expect(json[:commenter_display_name]).to eq('Imported Person')
        expect(json[:commenter_imported]).to be(true)
      end

      # Task 33 PII guard: redact to role label when only imported_email
      # is populated (see ImportedAttribution).
      it 'redacts to "(imported commenter)" when only imported_email is populated' do
        review.update_columns(user_id: nil, commenter_imported_email: 'imp@old.example')
        json = ReviewBlueprint.render_as_hash(review.reload)
        expect(json[:commenter_display_name]).to eq('(imported commenter)')
        expect(json[:commenter_imported]).to be(true)
      end

      it 'returns nil display_name + false imported when fully orphaned' do
        review.update_columns(user_id: nil)
        json = ReviewBlueprint.render_as_hash(review.reload)
        expect(json[:commenter_display_name]).to be_nil
        expect(json[:commenter_imported]).to be(false)
      end
    end

    # expand default fields to eliminate
    # the post-mutation refetch in CommentTriageModal. Today the modal
    # opens with a row hash from Component#paginated_comments, but after
    # /reviews/:id/triage|adjudicate|withdraw|update returns
    # ReviewBlueprint.render_as_hash, the response is missing several
    # fields the modal needs (rule_id, section, threading FKs, etc.).
    # The frontend has to refetch the parent table → 2 round trips per
    # mutation. Adding these fields to the blueprint default lets the
    # modal refresh in place from the response payload alone.
    describe 'expanded default fields (eliminate frontend refetch)' do
      it 'exposes rule_id (modal needs it for picker scope)' do
        json = ReviewBlueprint.render_as_hash(review)
        expect(json[:rule_id]).to eq(rule.id)
      end

      it 'exposes section (modal renders SectionLabel)' do
        review.update_columns(section: 'check_content')
        json = ReviewBlueprint.render_as_hash(review.reload)
        expect(json[:section]).to eq('check_content')
      end

      it 'exposes responding_to_review_id (modal distinguishes top-level vs reply)' do
        parent = Review.create!(user: user, rule: rule, action: 'comment', comment: 'parent')
        reply = Review.create!(user: user, rule: rule, action: 'comment',
                               comment: 'reply', responding_to_review_id: parent.id)
        json = ReviewBlueprint.render_as_hash(reply)
        expect(json[:responding_to_review_id]).to eq(parent.id)
      end

      it 'exposes duplicate_of_review_id (modal renders dup-target picker state)' do
        target = Review.create!(user: user, rule: rule, action: 'comment',
                                comment: 'target', triage_status: 'pending')
        review.update_columns(triage_status: 'duplicate', duplicate_of_review_id: target.id)
        json = ReviewBlueprint.render_as_hash(review.reload)
        expect(json[:duplicate_of_review_id]).to eq(target.id)
      end

      it 'exposes triage_set_by_id (forensic queries — admin-tier modal)' do
        review.update_columns(triage_set_by_id: user.id, triage_set_at: Time.current)
        json = ReviewBlueprint.render_as_hash(review.reload)
        expect(json[:triage_set_by_id]).to eq(user.id)
      end

      it 'exposes author_name (modal renders blockquote header)' do
        json = ReviewBlueprint.render_as_hash(review)
        expect(json[:author_name]).to eq(reviewer_name)
      end

      it 'still excludes user_id (sensitive — public-comment correlation guard)' do
        json = ReviewBlueprint.render_as_hash(review)
        expect(json).not_to have_key(:user_id)
      end

      it 'omits author_email by default (avoid scraping during open comment window)' do
        json = ReviewBlueprint.render_as_hash(review)
        expect(json).not_to have_key(:author_email)
      end

      it 'includes author_email when render is called with include_email: true' do
        json = ReviewBlueprint.render_as_hash(review, include_email: true)
        expect(json[:author_email]).to eq(reviewer_email)
      end

      it 'returns nil author_email when user is detached and include_email: true' do
        review.update_columns(user_id: nil, commenter_imported_email: 'imp@old.example')
        json = ReviewBlueprint.render_as_hash(review.reload, include_email: true)
        # Strict: author_email surfaces the User#email (the *current
        # account's* email, not the historic commenter_imported_email).
        # When user_id is nil there is no current account → nil. The
        # imported email lives on commenter_display_name's fallback chain.
        expect(json[:author_email]).to be_nil
      end
    end

    describe 'reactions field' do
      it 'returns zeros + nil mine when no reactions_summary option supplied' do
        json = ReviewBlueprint.render_as_hash(review)
        expect(json[:reactions]).to eq(up: 0, down: 0, mine: nil)
      end

      it 'reads counts and mine from reactions_summary option' do
        summary = { review.id => { up: 3, down: 1, mine: 'up' } }
        json = ReviewBlueprint.render_as_hash(review, reactions_summary: summary)
        expect(json[:reactions]).to eq(up: 3, down: 1, mine: 'up')
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
