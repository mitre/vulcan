# frozen_string_literal: true

require 'rails_helper'

# addressed_by triage on SRG-kind components. addressed_by_rule is a
# kind-agnostic BaseRule FK; these examples pin that the validators and
# terminal auto-adjudication behave for authored SrgRules exactly as for
# STIG rules, and document the tombstoned-target interaction: relocation
# execution tombstones the source (deleted_at set, row kept), the FK has
# no default scope so it still resolves, and later saves stay valid.
RSpec.describe Review do
  describe 'addressed_by triage (SRG kind)' do
    let_it_be(:project) { create(:project) }
    let_it_be(:srg_component) do
      create(:component, :skip_rules, project: project, document_type: 'srg')
    end
    let_it_be(:req_a) { create(:srg_rule, :authored, component: srg_component) }
    let_it_be(:req_b) { create(:srg_rule, :authored, component: srg_component) }
    let_it_be(:triager) do
      Membership.find_or_create_by!(user: create(:user, name: 'Triager'), membership: project) do |m|
        m.role = 'author'
      end.user
    end
    let_it_be(:commenter) do
      Membership.find_or_create_by!(user: create(:user, name: 'Commenter'), membership: project) do |m|
        m.role = 'viewer'
      end.user
    end

    def srg_comment(commentable: req_a, comment: 'srg comment text')
      create(:review, :comment, user: commenter, rule: nil, commentable: commentable, comment: comment)
    end

    it 'validates and auto-adjudicates addressed_by with an SrgRule target' do
      review = srg_comment
      review.update!(triage_status: 'addressed_by', addressed_by_rule_id: req_b.id,
                     triage_set_by_id: triager.id, triage_set_at: Time.current)

      review.reload
      expect(review.triage_status).to eq('addressed_by')
      expect(review.addressed_by_rule_id).to eq(req_b.id)
      expect(review.addressed_by_rule).to eq(req_b)
      expect(review.adjudicated_at).to be_present
      expect(review.adjudicated_by_id).to eq(triager.id)
    end

    it 'requires a target rule when triage_status is addressed_by' do
      review = srg_comment
      review.assign_attributes(triage_status: 'addressed_by',
                               triage_set_by_id: triager.id, triage_set_at: Time.current)

      expect(review).not_to be_valid
      expect(review.errors[:addressed_by_rule_id])
        .to include('is required when triage_status is addressed_by')
    end

    it 'enforces the same-rule reply guard for SRG threads (parity with STIG)' do
      parent = srg_comment

      valid_reply = build(:review, :comment, user: commenter, rule: nil, commentable: req_a,
                                             comment: 'same-target reply', triage_status: nil,
                                             responding_to_review_id: parent.id)
      expect(valid_reply).to be_valid

      cross_reply = build(:review, :comment, user: commenter, rule: nil, commentable: req_b,
                                             comment: 'cross-target reply', triage_status: nil,
                                             responding_to_review_id: parent.id)
      expect(cross_reply).not_to be_valid
      expect(cross_reply.errors[:responding_to_review_id])
        .to include('must reference a comment on the same rule')
    end

    describe 'multi-parent SRG component (component_source_srgs)' do
      it 'addressed_by across requirements derived from different parent SRGs validates and adjudicates' do
        primary = create(:security_requirements_guide, :core, :skip_rules,
                         srg_id: 'SRG-ADDR-MP-A', version: 'V1R1')
        secondary = create(:security_requirements_guide, :core, :skip_rules,
                           srg_id: 'SRG-ADDR-MP-B', version: 'V1R1')
        mp_component = create(:component, :skip_rules, project: project, document_type: 'srg',
                                                       based_on: primary, prefix: 'ADMP-00')
        mp_component.component_source_srgs.create!(security_requirements_guide: secondary)

        cat_a = create(:srg_rule, security_requirements_guide: primary, version: 'SRG-MP-000001')
        cat_b = create(:srg_rule, security_requirements_guide: secondary, version: 'SRG-MP-000002')
        req_from_a = create(:srg_rule, :authored, component: mp_component, rule_id: '400001',
                                                  derived_from_srg_rule_id: cat_a.id)
        req_from_b = create(:srg_rule, :authored, component: mp_component, rule_id: '400002',
                                                  derived_from_srg_rule_id: cat_b.id)

        review = create(:review, :comment, user: commenter, rule: nil,
                                           commentable: req_from_a, comment: 'multi-parent comment')
        review.update!(triage_status: 'addressed_by', addressed_by_rule_id: req_from_b.id,
                       triage_set_by_id: triager.id, triage_set_at: Time.current)

        review.reload
        expect(review.addressed_by_rule).to eq(req_from_b)
        # The consumer surface directly: the triage-row decoration resolves
        # the cross-parent target's displayed name through the component-
        # scoped display map — proof no addressed_by surface reads based_on.
        row = CommentQueryService.new(mp_component).call[:rows]
                                 .find { |r| r['id'] == review.id }
        expect(row['addressed_by_rule_name']).to eq('ADMP-00-400002')
      end
    end

    describe 'relocated addressed_by target (executed relocation tombstones the source)' do
      it 'keeps the FK resolvable and the review valid after the target relocates away' do
        core = create(:security_requirements_guide, :core, :skip_rules,
                      srg_id: 'SRG-ADDR-RELOC', version: 'V1R1')
        catalog_row = create(:srg_rule, security_requirements_guide: core, version: 'SRG-RL-000001')
        source_component = create(:component, :skip_rules, project: project, document_type: 'srg',
                                                           based_on: core, prefix: 'ADRS-00')
        dest_component = create(:component, :skip_rules, project: project, document_type: 'srg',
                                                         based_on: core, prefix: 'ADRT-00')
        commented = create(:srg_rule, :authored, component: source_component, rule_id: '500001')
        target = create(:srg_rule, :authored, component: source_component, rule_id: '500002',
                                              derived_from_srg_rule_id: catalog_row.id)

        review = create(:review, :comment, user: commenter, rule: nil,
                                           commentable: commented, comment: 'reloc target comment')
        review.update!(triage_status: 'addressed_by', addressed_by_rule_id: target.id,
                       triage_set_by_id: triager.id, triage_set_at: Time.current)

        relocation = RequirementRelocation.create!(source_rule: target,
                                                   target_technology_token: 'ADRT',
                                                   requested_by: triager)
        RelocationExecutor.new(relocation, target_component: dest_component,
                                           accepted_by: triager).execute!

        review.reload
        expect(review.addressed_by_rule).to eq(target)
        expect(review.addressed_by_rule.deleted_at).to be_present
        # The tombstone leaves the live requirement set (display maps built
        # from it fall back to the id badge), but the FK row still resolves.
        expect(source_component.requirements.ids).not_to include(target.id)

        review.comment = "#{review.comment} (edited)"
        expect(review.save).to be(true)
        expect(review.reload.addressed_by_rule_id).to eq(target.id)
      end
    end
  end
end
