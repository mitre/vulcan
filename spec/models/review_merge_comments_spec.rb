# frozen_string_literal: true

require 'rails_helper'

# Merges N same-author comments within one component into a designated
# survivor: secondaries get triage_status='duplicate' pointing at the
# survivor, the survivor's comment is annotated with the originating rule
# labels, and the per-row audits share the request's request_uuid.
RSpec.describe Review, '.merge_comments!' do
  let_it_be(:project) { create(:project) }
  let_it_be(:component) do
    create(:component, project: project,
                       comment_phase: 'open',
                       comment_period_starts_at: 1.day.ago,
                       comment_period_ends_at: 1.day.from_now)
  end
  let_it_be(:rule_a) { component.rules.first }
  let_it_be(:rule_b) { component.rules.second }
  let_it_be(:rule_c) { component.rules.third }
  let_it_be(:other_component) { create(:component, project: project) }
  let_it_be(:rule_other) { other_component.rules.first }

  let_it_be(:admin) do
    Membership.find_or_create_by!(user: create(:user, name: 'Admin'), membership: project) { |m| m.role = 'admin' }.user
  end
  let_it_be(:commenter) do
    Membership.find_or_create_by!(user: create(:user, name: 'Commenter'), membership: project) { |m| m.role = 'viewer' }.user
  end
  let_it_be(:other_commenter) do
    Membership.find_or_create_by!(user: create(:user, name: 'Other'), membership: project) { |m| m.role = 'viewer' }.user
  end

  def cmt(rule:, user: commenter, text: 'logging not applicable')
    create(:review, :comment, user: user, rule: rule, comment: text)
  end

  it 'merges selected reviews into one and marks others as duplicate' do
    survivor = cmt(rule: rule_a)
    dup_b    = cmt(rule: rule_b)
    dup_c    = cmt(rule: rule_c)

    Review.merge_comments!(survivor: survivor, duplicates: [dup_b, dup_c], merged_by: admin)

    [dup_b, dup_c].each do |d|
      d.reload
      expect(d.triage_status).to eq('duplicate')
      expect(d.duplicate_of_review_id).to eq(survivor.id)
      expect(d.triage_set_by_id).to eq(admin.id)
      expect(d.triage_set_at).to be_within(5.seconds).of(Time.current)
    end
    expect(survivor.reload.triage_status).not_to eq('duplicate') # survivor stays itself
  end

  it 'auto-adjudicates the duplicates (terminal status)' do
    survivor = cmt(rule: rule_a)
    dup      = cmt(rule: rule_b)

    Review.merge_comments!(survivor: survivor, duplicates: [dup], merged_by: admin)

    expect(dup.reload.adjudicated_at).to be_within(5.seconds).of(Time.current)
  end

  it 'prepends a merged-from marker naming the originating rule labels' do
    survivor = cmt(rule: rule_a, text: 'original concern text')
    dup_b    = cmt(rule: rule_b)
    dup_c    = cmt(rule: rule_c)

    Review.merge_comments!(survivor: survivor, duplicates: [dup_b, dup_c], merged_by: admin)

    survivor.reload
    expected_label_b = "#{component.prefix}-#{rule_b.rule_id}"
    expected_label_c = "#{component.prefix}-#{rule_c.rule_id}"
    expect(survivor.comment).to include('[Merged: originally posted on')
    expect(survivor.comment).to include(expected_label_b)
    expect(survivor.comment).to include(expected_label_c)
    expect(survivor.comment).to include('original concern text') # body preserved
  end

  it 'rejects merging comments from different commenters' do
    survivor = cmt(rule: rule_a)
    foreign  = cmt(rule: rule_b, user: other_commenter)

    expect do
      Review.merge_comments!(survivor: survivor, duplicates: [foreign], merged_by: admin)
    end.to raise_error(ArgumentError, /same commenter/i)

    expect(foreign.reload.triage_status).to eq('pending')
  end

  it 'rejects merging comments spanning multiple components' do
    survivor = cmt(rule: rule_a)
    foreign  = cmt(rule: rule_other, user: commenter)

    expect do
      Review.merge_comments!(survivor: survivor, duplicates: [foreign], merged_by: admin)
    end.to raise_error(ArgumentError, /multiple components/i)

    expect(foreign.reload.triage_status).to eq('pending')
  end

  it 'rejects an empty duplicates list' do
    survivor = cmt(rule: rule_a)
    expect do
      Review.merge_comments!(survivor: survivor, duplicates: [], merged_by: admin)
    end.to raise_error(ArgumentError, /At least one/i)
  end

  it 'ignores a duplicate-list entry that is the survivor itself' do
    survivor = cmt(rule: rule_a)
    dup      = cmt(rule: rule_b)

    Review.merge_comments!(survivor: survivor, duplicates: [survivor, dup], merged_by: admin)

    expect(survivor.reload.triage_status).not_to eq('duplicate')
    expect(dup.reload.triage_status).to eq('duplicate')
  end
end
