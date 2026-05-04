# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: Comment-listing endpoints (the triage table) must NOT
# expose commenter email addresses. The endpoints are accessible to
# every project member (and, for released components, every logged-in
# user), so leaking email enables scraping of every commenter's
# contact info during a public review window — a real threat for
# the Container SRG window with ~25 industry commenters.
#
# Author NAME is OK to expose (the audit trail and triage UI need it);
# email is the PII leak vector and should never appear in the row hash.
RSpec.describe 'paginated_comments — PII shape' do
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project, based_on: srg) }
  let_it_be(:viewer) { create(:user, name: 'Industry Commenter', email: 'pii-leak@example.com') }

  let_it_be(:posted_review) do
    Membership.find_or_create_by!(user: viewer, membership: project) { |m| m.role = 'viewer' }
    Review.create!(action: 'comment', user: viewer, rule: component.rules.first,
                   comment: 'spec-fixture comment')
  end

  describe 'Component#paginated_comments' do
    it 'includes the author name but never the author email' do
      row = component.paginated_comments[:rows].first
      expect(row[:author_name]).to eq('Industry Commenter')
      expect(row).not_to have_key(:author_email)
      expect(row.values).not_to include(viewer.email)
    end
  end

  describe 'Project#paginated_comments' do
    it 'includes the author name but never the author email' do
      row = project.paginated_comments[:rows].first
      expect(row[:author_name]).to eq('Industry Commenter')
      expect(row).not_to have_key(:author_email)
      expect(row.values).not_to include(viewer.email)
    end
  end

  # paginated_comments rows feed the comment
  # triage table directly into CommentTriageModal (no extra fetch). The modal
  # renders "Triaged by ... · time / Adjudicated by ... · time" with an
  # "imported" badge when the FK is nil and imported_* attribution survives
  # from a JSON archive restore. Tests assert the row hash carries the four
  # display fields the modal expects.
  describe 'attribution display fields' do
    let_it_be(:triager) { create(:user, name: 'Tri Ager', email: 'triager@test.com') }

    before do
      Membership.find_or_create_by!(user: triager, membership: project) { |m| m.role = 'admin' }
      posted_review.update_columns(
        triage_status: 'concur',
        triage_set_by_id: triager.id,
        triage_set_at: Time.current
      )
    end

    it 'Component#paginated_comments includes triager_display_name + triager_imported' do
      row = component.paginated_comments[:rows].first
      expect(row[:triager_display_name]).to eq('Tri Ager')
      expect(row[:triager_imported]).to be(false)
      expect(row).to have_key(:adjudicator_display_name)
      expect(row).to have_key(:adjudicator_imported)
    end

    it 'falls back to imported attribution when FK is nil' do
      posted_review.update_columns(
        triage_set_by_id: nil,
        triage_set_by_imported_name: 'Old Triager',
        triage_set_by_imported_email: 'old@former.example'
      )
      row = component.paginated_comments[:rows].first
      expect(row[:triager_display_name]).to eq('Old Triager')
      expect(row[:triager_imported]).to be(true)
    end

    # PII redaction: when ONLY the imported_email column is populated
    # (not imported_name), the display fallback redacts to a role token
    # rather than leaking the raw email. JSON archives can carry real
    # emails from a source instance; surfacing them through every read
    # surface during a public comment window is a scrape vector.
    it 'redacts triager fallback when only imported_email is populated' do
      posted_review.update_columns(
        triage_set_by_id: nil,
        triage_set_by_imported_name: nil,
        triage_set_by_imported_email: 'leak-me@example.com'
      )
      row = component.paginated_comments[:rows].first
      expect(row[:triager_display_name]).to eq('(imported triager)')
      expect(row[:triager_imported]).to be(true)
      expect(row.values).not_to include('leak-me@example.com')
    end

    it 'redacts commenter fallback when only commenter_imported_email is populated' do
      posted_review.update_columns(
        user_id: nil,
        commenter_imported_name: nil,
        commenter_imported_email: 'commenter-leak@example.com'
      )
      row = component.paginated_comments[:rows].first
      expect(row[:commenter_display_name]).to eq('(imported commenter)')
      expect(row[:commenter_imported]).to be(true)
      expect(row.values).not_to include('commenter-leak@example.com')
    end

    it 'Project#paginated_comments carries the same four display fields' do
      row = project.paginated_comments[:rows].first
      expect(row[:triager_display_name]).to eq('Tri Ager')
      expect(row[:triager_imported]).to be(false)
      expect(row).to have_key(:adjudicator_display_name)
      expect(row).to have_key(:adjudicator_imported)
    end
  end

  # Task 33: row payloads carry a responses_count so the read surfaces
  # can show "N replies" without N+1 fetches. Replies are lazy-loaded
  # via GET /reviews/:id/responses on expand.
  describe 'responses_count on row payloads' do
    let_it_be(:replier) do
      u = create(:user, name: 'Replier', email: 'replier@example.com')
      Membership.find_or_create_by!(user: u, membership: project) { |m| m.role = 'viewer' }
      u
    end

    before do
      Review.create!(action: 'comment', comment: 'first reply', user: replier,
                     rule: posted_review.rule, responding_to_review_id: posted_review.id)
      Review.create!(action: 'comment', comment: 'second reply', user: replier,
                     rule: posted_review.rule, responding_to_review_id: posted_review.id)
    end

    it 'Component#paginated_comments includes responses_count' do
      row = component.paginated_comments[:rows].find { |r| r[:id] == posted_review.id }
      expect(row[:responses_count]).to eq(2)
    end

    it 'Project#paginated_comments includes responses_count' do
      row = project.paginated_comments[:rows].find { |r| r[:id] == posted_review.id }
      expect(row[:responses_count]).to eq(2)
    end

    it 'returns 0 when a top-level comment has no replies' do
      lone = Review.create!(action: 'comment', comment: 'lone', user: replier, rule: posted_review.rule)
      row = component.paginated_comments[:rows].find { |r| r[:id] == lone.id }
      expect(row[:responses_count]).to eq(0)
    end
  end
end
