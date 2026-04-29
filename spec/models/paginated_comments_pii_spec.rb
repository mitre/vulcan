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
end
