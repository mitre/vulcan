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

    before_call = Time.current.floor(6)
    Review.merge_comments!(survivor: survivor, duplicates: [dup_b, dup_c], merged_by: admin)
    after_call = Time.current

    [dup_b, dup_c].each do |d|
      d.reload
      expect(d.triage_status).to eq('duplicate')
      expect(d.duplicate_of_review_id).to eq(survivor.id)
      expect(d.triage_set_by_id).to eq(admin.id)
      expect(d.triage_set_at).to be_between(before_call, after_call)
    end
    expect(survivor.reload.triage_status).not_to eq('duplicate') # survivor stays itself
  end

  it 'auto-adjudicates the duplicates (terminal status)' do
    survivor = cmt(rule: rule_a)
    dup      = cmt(rule: rule_b)

    before_call = Time.current.floor(6)
    Review.merge_comments!(survivor: survivor, duplicates: [dup], merged_by: admin)
    after_call = Time.current

    expect(dup.reload.adjudicated_at).to be_between(before_call, after_call)
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

  it 'raises ArgumentError when merged_by is nil — before any writes' do
    survivor = cmt(rule: rule_a, text: 'guard survivor text')
    dup      = cmt(rule: rule_b)

    expect do
      Review.merge_comments!(survivor: survivor, duplicates: [dup], merged_by: nil)
    end.to raise_error(ArgumentError, 'merged_by is required.')

    # Fail-fast contract: the survivor was never marked and the duplicate
    # never re-statused.
    expect(survivor.reload.comment).to eq('guard survivor text')
    expect(dup.reload.triage_status).not_to eq('duplicate')
  end

  # Kind seam: an authored-SrgRule comment has a nil Rule-STI `rule`
  # association — the merge marker's source labels must come from the
  # kind-aware accessors.
  context 'between authored SRG requirements' do
    let_it_be(:srg_component) do
      create(:component, :skip_rules, project: project, document_type: 'srg')
    end
    let_it_be(:authored_a) { create(:srg_rule, :authored, component: srg_component) }
    let_it_be(:authored_b) { create(:srg_rule, :authored, component: srg_component) }

    it 'merges authored-requirement comments with the requirement label in the marker' do
      survivor = create(:review, :comment, user: commenter, rule: nil,
                                           commentable: authored_a, comment: 'seam survivor')
      dup = create(:review, :comment, user: commenter, rule: nil,
                                      commentable: authored_b, comment: 'seam duplicate')

      Review.merge_comments!(survivor: survivor, duplicates: [dup], merged_by: admin)

      expect(survivor.reload.comment)
        .to start_with("[Merged: originally posted on #{srg_component.prefix}-#{authored_b.rule_id}]")
      expect(dup.reload.triage_status).to eq('duplicate')
      expect(dup.duplicate_of_review_id).to eq(survivor.id)
    end
  end

  # Scope seam: a component-scoped comment has no requirement at all —
  # its original location is the component itself, so the marker labels
  # it with the bare prefix.
  it 'merges a component-scoped duplicate with the bare component prefix as its label' do
    survivor = cmt(rule: rule_a)
    dup = create(:review, :component_comment, user: commenter,
                                              commentable: component, comment: 'posted at component level')

    Review.merge_comments!(survivor: survivor, duplicates: [dup], merged_by: admin)

    expect(survivor.reload.comment)
      .to start_with("[Merged: originally posted on #{component.prefix}]")
    expect(dup.reload.triage_status).to eq('duplicate')
    expect(dup.duplicate_of_review_id).to eq(survivor.id)
  end
end
