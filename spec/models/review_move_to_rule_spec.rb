# frozen_string_literal: true

require 'rails_helper'

# admin-moves a comment from one rule to another inside
# the same component. Sets original_commentable_id (first-move only),
# prepends a "[Moved from …]" marker, cascades to replies, writes an audit
# row via vulcan_audited.
RSpec.describe Review, '#move_to_rule!' do
  let_it_be(:project) { create(:project) }
  let_it_be(:component) do
    create(:component, project: project,
                       comment_phase: 'open',
                       comment_period_starts_at: 1.day.ago,
                       comment_period_ends_at: 1.day.from_now)
  end
  let_it_be(:rule_src)    { component.rules.first }
  let_it_be(:rule_target) { component.rules.second }
  let_it_be(:rule_third)  { component.rules.third }
  let_it_be(:other_component) { create(:component, project: project) }
  let_it_be(:rule_other) { other_component.rules.first }

  let_it_be(:admin) do
    Membership.find_or_create_by!(user: create(:user, name: 'Admin'), membership: project) { |m| m.role = 'admin' }.user
  end
  let_it_be(:commenter) do
    Membership.find_or_create_by!(user: create(:user, name: 'Commenter'), membership: project) { |m| m.role = 'viewer' }.user
  end

  def fresh_review(rule: rule_src, comment: 'original text')
    create(:review, :comment, user: commenter, rule: rule, comment: comment)
  end

  it 'moves review to target rule and sets original_commentable_id' do
    review = fresh_review
    review.move_to_rule!(rule_target, reason: 'wrong rule', moved_by: admin)

    review.reload
    expect(review.rule_id).to eq(rule_target.id)
    expect(review.commentable_id).to eq(rule_target.id)
    expect(review.commentable_type).to eq('BaseRule')
    expect(review.original_commentable_id).to eq(rule_src.id)
  end

  it "prepends '[Moved from {prefix}-{rule_id}: {reason}]' to the comment" do
    review = fresh_review(comment: 'original text')
    review.move_to_rule!(rule_target, reason: 'wrong rule', moved_by: admin)
    expect(review.reload.comment).to start_with("[Moved from #{component.prefix}-#{rule_src.rule_id}: wrong rule]")
    expect(review.comment).to include('original text')
  end

  it 'preserves first-move provenance — does not overwrite original_commentable_id on a second move' do
    review = fresh_review
    review.move_to_rule!(rule_target, reason: 'first move', moved_by: admin)
    review.move_to_rule!(rule_third,  reason: 'second move', moved_by: admin)
    expect(review.reload.original_commentable_id).to eq(rule_src.id)
  end

  it 'rejects a target rule in a different component' do
    review = fresh_review
    expect do
      review.move_to_rule!(rule_other, reason: 'cross-component', moved_by: admin)
    end.to raise_error(ArgumentError, /same component/i)
    expect(review.reload.rule_id).to eq(rule_src.id)
  end

  it 'rejects a blank reason' do
    review = fresh_review
    expect do
      review.move_to_rule!(rule_target, reason: '', moved_by: admin)
    end.to raise_error(ArgumentError, /reason/i)
  end

  it 'cascades to replies (incl. reply-of-reply) — depth ≥ 2' do
    parent = fresh_review
    reply  = create(:review, :comment, user: commenter, rule: rule_src,
                                       comment: 'a reply', responding_to_review_id: parent.id)
    nested = create(:review, :comment, user: commenter, rule: rule_src,
                                       comment: 'reply to reply', responding_to_review_id: reply.id)

    parent.move_to_rule!(rule_target, reason: 'cascade test', moved_by: admin)

    [reply, nested].each(&:reload)
    expect(reply.rule_id).to eq(rule_target.id)
    expect(reply.commentable_id).to eq(rule_target.id)
    expect(reply.original_commentable_id).to eq(rule_src.id)
    expect(nested.rule_id).to eq(rule_target.id)
    expect(nested.commentable_id).to eq(rule_target.id)
  end

  context 'audit trail' do
    include_context 'with auditing'

    it 'writes an audit row with audit_comment naming the move' do
      review = fresh_review
      expect do
        review.move_to_rule!(rule_target, reason: 'audit check', moved_by: admin)
      end.to change { review.audits.count }.by_at_least(1)
      last_audit = review.audits.last
      expect(last_audit.comment).to include("#{component.prefix}-#{rule_target.rule_id}")
      expect(last_audit.comment).to include('audit check')
    end
  end

  # Kind seam: an authored-SrgRule comment has a nil Rule-STI `rule`
  # association — the guard, the provenance marker, and the target
  # assignment must all run on the kind-aware columns/accessors.
  context 'between authored SRG requirements' do
    let_it_be(:srg_component) do
      create(:component, :skip_rules, project: project, document_type: 'srg')
    end
    let_it_be(:authored_src) { create(:srg_rule, :authored, component: srg_component) }
    let_it_be(:authored_target) { create(:srg_rule, :authored, component: srg_component) }

    it 'moves the review and dual-writes rule_id for the SrgRule target' do
      review = create(:review, :comment, user: commenter, rule: nil,
                                         commentable: authored_src, comment: 'seam text')
      review.move_to_rule!(authored_target, reason: 'kind seam', moved_by: admin)

      review.reload
      expect(review.commentable_id).to eq(authored_target.id)
      expect(review.commentable_type).to eq('BaseRule')
      expect(review.rule_id).to eq(authored_target.id)
      expect(review.original_commentable_id).to eq(authored_src.id)
      expect(review.comment)
        .to start_with("[Moved from #{srg_component.prefix}-#{authored_src.rule_id}: kind seam]")
    end
  end
end
