# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENTS (PR #717 Task 23):
#
# 1. SatisfactionBlueprint exposes pending_comment_count + total_comment_count
#    so the rule editor's Satisfies panel can show triagers/commenters where
#    prior conversation lives across related rules — without inheriting or
#    merging comment data.
# 2. Counts are TOP-LEVEL ONLY (responding_to_review_id IS NULL). Replies
#    don't represent new pending work.
# 3. Counts are computed in-memory against the eager-loaded :reviews
#    association so we don't N+1 with one COUNT per related-rule row.
# 4. SatisfiedByBlueprint inherits the count fields automatically.
RSpec.describe SatisfactionBlueprint do
  let(:project) { create(:project) }
  let(:component) { create(:component, :skip_rules, project: project) }
  let(:user) { create(:user) }
  let(:rule_a) { create(:rule, component: component) }
  let(:rule_b) { create(:rule, component: component) }

  before do
    rule_a.satisfied_by << rule_b
    Review.create!(rule: rule_b, user: user, action: 'comment',
                   comment: 'pending one', triage_status: 'pending')
    Review.create!(rule: rule_b, user: user, action: 'comment',
                   comment: 'concur one', triage_status: 'concur')
    parent = Review.create!(rule: rule_b, user: user, action: 'comment',
                            comment: 'pending two', triage_status: 'pending')
    Review.create!(rule: rule_b, user: user, action: 'comment',
                   comment: 'a reply', triage_status: 'pending',
                   responding_to_review_id: parent.id)
  end

  it 'exposes pending_comment_count and total_comment_count fields' do
    json = JSON.parse(SatisfactionBlueprint.render(rule_b))
    expect(json).to include('pending_comment_count', 'total_comment_count')
  end

  it 'counts top-level comments only (excludes replies)' do
    json = JSON.parse(SatisfactionBlueprint.render(rule_b))
    expect(json['total_comment_count']).to eq(3)
    expect(json['pending_comment_count']).to eq(2)
  end

  it 'returns zero when the rule has no top-level comments' do
    rule_c = create(:rule, component: component)
    json = JSON.parse(SatisfactionBlueprint.render(rule_c))
    expect(json['pending_comment_count']).to eq(0)
    expect(json['total_comment_count']).to eq(0)
  end

  describe 'SatisfiedByBlueprint inherits the count fields' do
    it 'includes pending_comment_count and total_comment_count' do
      json = JSON.parse(SatisfiedByBlueprint.render(rule_b))
      expect(json).to include('pending_comment_count', 'total_comment_count')
    end
  end
end
