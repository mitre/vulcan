# frozen_string_literal: true

require 'rails_helper'

# Coverage for Component.pending_comment_counts — the aggregate count
# query used by the project-detail page to render a "N pending" badge
# on each component card without N+1 queries (PR #717 follow-on,
# extending the projects-list pattern in Project.pending_comment_counts).
RSpec.describe Component do
  describe '.pending_comment_counts' do
    let_it_be(:srg) { create(:security_requirements_guide) }
    let_it_be(:project) { create(:project) }
    let_it_be(:component_a) { create(:component, project: project, based_on: srg) }
    let_it_be(:component_b) { create(:component, project: project, based_on: srg) }
    let_it_be(:component_c) { create(:component, project: project, based_on: srg) }
    let_it_be(:viewer) { create(:user) }
    let_it_be(:author) { create(:user) }

    before_all do
      create(:membership, user: viewer, membership: project, role: 'viewer')

      # Component A: 2 pending top-level + 1 reply (excluded) + 1 already-triaged (excluded)
      Review.create!(action: 'comment', comment: 'a-pending-1', user: viewer,
                     rule: component_a.rules.first)
      Review.create!(action: 'comment', comment: 'a-pending-2', user: viewer,
                     rule: component_a.rules.first)
      parent = Review.create!(action: 'comment', comment: 'a-parent', user: viewer,
                              rule: component_a.rules.first)
      Review.create!(action: 'comment', comment: 'a-reply', user: viewer,
                     rule: component_a.rules.first,
                     responding_to_review_id: parent.id)
      parent.update!(triage_status: 'concur', triage_set_by_id: author.id, triage_set_at: Time.current)

      # Component B: 1 pending top-level
      Review.create!(action: 'comment', comment: 'b-pending', user: viewer,
                     rule: component_b.rules.first)

      # Component C: zero pending — should be omitted from result
    end

    it 'returns a hash keyed by component_id with pending top-level counts' do
      counts = described_class.pending_comment_counts(
        [component_a.id, component_b.id, component_c.id]
      )
      expect(counts[component_a.id]).to eq(2)
      expect(counts[component_b.id]).to eq(1)
    end

    it 'omits components with zero pending comments from the hash (sparse)' do
      counts = described_class.pending_comment_counts(
        [component_a.id, component_b.id, component_c.id]
      )
      expect(counts).not_to have_key(component_c.id)
    end

    it 'returns an empty hash when given an empty array' do
      expect(described_class.pending_comment_counts([])).to eq({})
    end

    it 'issues a single SQL query (no N+1 across components)' do
      component_ids = [component_a.id, component_b.id, component_c.id]
      query_count = 0
      counter = lambda do |_name, _start, _finish, _id, payload|
        next if payload[:name] == 'SCHEMA' || payload[:sql] =~ /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i

        query_count += 1
      end
      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
        described_class.pending_comment_counts(component_ids)
      end
      expect(query_count).to eq(1)
    end
  end
end
