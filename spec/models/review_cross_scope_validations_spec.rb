# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: structured cross-references on a Review (responding_to_review_id
# and duplicate_of_review_id) must point to a Review that lives within the
# same scope as the new Review:
#
# - responding_to_review_id → must reference a comment on the SAME RULE
#   (a thread reply only makes sense within one rule's discussion)
# - duplicate_of_review_id → must reference a top-level comment on the
#   SAME COMPONENT (cross-project / cross-component duplicates are
#   meaningless and risk leaking row IDs across project boundaries)
#
# Without these guards, a viewer/author can craft requests that link
# Reviews across project boundaries — confusing the audit trail and
# enabling cross-project metadata enumeration via review IDs.
RSpec.describe Review do
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:project_a) { create(:project) }
  let_it_be(:project_b) { create(:project) }
  let_it_be(:component_a1) { create(:component, project: project_a, based_on: srg) }
  let_it_be(:component_a2) { create(:component, project: project_a, based_on: srg) }
  let_it_be(:component_b1) { create(:component, project: project_b, based_on: srg) }
  let_it_be(:viewer) { create(:user) }
  let_it_be(:author) { create(:user) }

  before_all do
    Membership.find_or_create_by!(user: viewer, membership: project_a) { |m| m.role = 'viewer' }
    Membership.find_or_create_by!(user: viewer, membership: project_b) { |m| m.role = 'viewer' }
    Membership.find_or_create_by!(user: author, membership: project_a) { |m| m.role = 'author' }
  end

  describe 'responding_to_review_id scoping' do
    let(:original_in_a1) do
      Review.create!(action: 'comment', user: viewer, rule: component_a1.rules.first,
                     comment: 'original on a1')
    end

    it 'rejects a reply that targets a comment on a different rule (different component)' do
      reply = Review.new(action: 'comment', user: viewer,
                         rule: component_a2.rules.first,
                         comment: 'misplaced reply',
                         responding_to_review_id: original_in_a1.id)
      expect(reply).not_to be_valid
      expect(reply.errors[:responding_to_review_id])
        .to include(/same rule/i).or include(/different rule/i)
    end

    it 'rejects a reply that targets a comment on a different rule (same component)' do
      another_rule_in_a1 = component_a1.rules.second
      reply = Review.new(action: 'comment', user: viewer,
                         rule: another_rule_in_a1,
                         comment: 'misplaced reply within same component',
                         responding_to_review_id: original_in_a1.id)
      expect(reply).not_to be_valid
      expect(reply.errors[:responding_to_review_id])
        .to include(/same rule/i).or include(/different rule/i)
    end

    it 'accepts a reply that targets a comment on the SAME rule' do
      reply = Review.new(action: 'comment', user: viewer,
                         rule: component_a1.rules.first,
                         comment: 'on-rule reply',
                         responding_to_review_id: original_in_a1.id)
      expect(reply).to be_valid
    end
  end

  describe 'duplicate_of_review_id scoping' do
    let(:original_in_a1) do
      Review.create!(action: 'comment', user: viewer, rule: component_a1.rules.first,
                     comment: 'first occurrence on a1')
    end

    it 'rejects a duplicate that targets a comment in a different project' do
      original_in_b1 = Review.create!(action: 'comment', user: viewer,
                                      rule: component_b1.rules.first,
                                      comment: 'unrelated comment in project B')
      dup = Review.new(action: 'comment', user: viewer,
                       rule: component_a1.rules.first,
                       comment: 'cross-project duplicate attempt',
                       triage_status: 'duplicate',
                       triage_set_by_id: author.id, triage_set_at: Time.current,
                       duplicate_of_review_id: original_in_b1.id)
      expect(dup).not_to be_valid
      expect(dup.errors[:duplicate_of_review_id])
        .to include(/same component/i)
    end

    it 'rejects a duplicate that targets a comment in a different component (same project)' do
      original_in_a2 = Review.create!(action: 'comment', user: viewer,
                                      rule: component_a2.rules.first,
                                      comment: 'unrelated comment on a2')
      dup = Review.new(action: 'comment', user: viewer,
                       rule: component_a1.rules.first,
                       comment: 'cross-component duplicate attempt',
                       triage_status: 'duplicate',
                       triage_set_by_id: author.id, triage_set_at: Time.current,
                       duplicate_of_review_id: original_in_a2.id)
      expect(dup).not_to be_valid
      expect(dup.errors[:duplicate_of_review_id])
        .to include(/same component/i)
    end

    it 'accepts a duplicate that targets a comment on the same component' do
      another_in_a1 = Review.create!(action: 'comment', user: viewer,
                                     rule: component_a1.rules.first,
                                     comment: 'first occurrence')
      dup = Review.new(action: 'comment', user: viewer,
                       rule: component_a1.rules.first,
                       comment: 'duplicate of the first',
                       triage_status: 'duplicate',
                       triage_set_by_id: author.id, triage_set_at: Time.current,
                       duplicate_of_review_id: another_in_a1.id)
      expect(dup).to be_valid
      _ = original_in_a1
    end
  end
end
