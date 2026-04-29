# frozen_string_literal: true

require 'rails_helper'

# Coverage for Project.pending_comment_counts — the aggregate count
# query used by the projects-list page to render a "N pending comments"
# badge per project (PR #717 follow-on).
RSpec.describe Project do
  describe '.pending_comment_counts' do
    let_it_be(:srg) { create(:security_requirements_guide) }
    let_it_be(:project_a) { create(:project) }
    let_it_be(:project_b) { create(:project) }
    let_it_be(:component_a1) { create(:component, project: project_a, based_on: srg) }
    let_it_be(:component_a2) { create(:component, project: project_a, based_on: srg) }
    let_it_be(:component_b1) { create(:component, project: project_b, based_on: srg) }
    let_it_be(:viewer) { create(:user) }
    let_it_be(:author) { create(:user) }

    before_all do
      create(:membership, user: viewer, membership: project_a, role: 'viewer')
      create(:membership, user: viewer, membership: project_b, role: 'viewer')

      # Project A: 2 pending top-level comments + 1 reply (excluded) + 1 concur
      Review.create!(action: 'comment', comment: 'a1-pending', user: viewer,
                     rule: component_a1.rules.first)
      Review.create!(action: 'comment', comment: 'a2-pending', user: viewer,
                     rule: component_a2.rules.first)
      parent = Review.create!(action: 'comment', comment: 'a1-parent', user: viewer,
                              rule: component_a1.rules.first)
      Review.create!(action: 'comment', comment: 'a1-reply', user: viewer,
                     rule: component_a1.rules.first,
                     responding_to_review_id: parent.id)
      parent.update!(triage_status: 'concur', triage_set_by_id: author.id, triage_set_at: Time.current)

      # Project B: 1 pending top-level comment
      Review.create!(action: 'comment', comment: 'b1-pending', user: viewer,
                     rule: component_b1.rules.first)
    end

    it 'returns a hash keyed by project_id with pending top-level counts' do
      counts = described_class.pending_comment_counts([project_a.id, project_b.id])
      # Project A had 3 top-level top-level comments — but parent was triaged to 'concur',
      # so only 2 remain pending. The reply is excluded by responding_to_review_id IS NULL.
      expect(counts[project_a.id]).to eq(2)
      expect(counts[project_b.id]).to eq(1)
    end

    it 'omits projects with zero pending comments from the hash (sparse)' do
      empty_project = create(:project)
      counts = described_class.pending_comment_counts(
        [project_a.id, project_b.id, empty_project.id]
      )
      expect(counts).not_to have_key(empty_project.id)
    end

    it 'returns an empty hash when given an empty array' do
      expect(described_class.pending_comment_counts([])).to eq({})
    end

    it 'issues a single SQL query (no N+1 across projects)' do
      project_ids = [project_a.id, project_b.id]
      query_count = 0
      counter = lambda do |_name, _start, _finish, _id, payload|
        # Skip schema/transaction/cache queries — only count actual SELECTs from app code
        next if payload[:name] == 'SCHEMA' || payload[:sql] =~ /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i

        query_count += 1
      end
      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
        described_class.pending_comment_counts(project_ids)
      end
      expect(query_count).to eq(1)
    end
  end
end
