# frozen_string_literal: true

require 'rails_helper'

##
# RuleBlueprint Tests
#
# REQUIREMENT: The :editor view must produce output that is field-compatible
# with the current Rule#as_json override, so Vue components continue to work.
# The :navigator view is a lightweight subset for the sidebar rule list.
#
RSpec.describe 'RuleBlueprint' do
  let_it_be(:srg) do
    srg_xml = Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read
    parsed = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed)
    srg.xml = srg_xml
    srg.save!
    srg
  end
  let_it_be(:component) { create(:component, based_on: srg) }
  let_it_be(:rule) do
    component.rules.eager_load(
      :reviews, :disa_rule_descriptions, :rule_descriptions, :checks,
      :additional_answers, { satisfies: :srg_rule }, { satisfied_by: :srg_rule },
      { srg_rule: %i[disa_rule_descriptions rule_descriptions checks security_requirements_guide] }
    ).first
  end

  describe ':editor view' do
    let(:json) { RuleBlueprint.render_as_json(rule, view: :editor) }

    it 'includes base rule columns' do
      %w[id rule_id title version rule_severity rule_weight status
         status_justification fixtext fixtext_fixref ident ident_system
         vendor_comments artifact_description component_id locked
         review_requestor_id changes_requested vuln_id legacy_ids
         inspec_control_body inspec_control_file locked_fields].each do |field|
        expect(json).to have_key(field), "Missing field: #{field}"
      end
    end

    it 'includes computed fields' do
      expect(json).to have_key('nist_control_family')
      expect(json).to have_key('srg_id')
      expect(json).to have_key('srg_info')
      expect(json['srg_info']).to have_key('version')
    end

    it 'includes nested associations as _attributes keys' do
      expect(json).to have_key('rule_descriptions_attributes')
      expect(json).to have_key('disa_rule_descriptions_attributes')
      expect(json).to have_key('checks_attributes')
      expect(json).to have_key('additional_answers_attributes')
      expect(json).to have_key('srg_rule_attributes')
    end

    it 'includes reviews without user_id (PII guard)' do
      expect(json).to have_key('reviews')
      if json['reviews'].any?
        review = json['reviews'].first
        expect(review).to have_key('id')
        expect(review).to have_key('name')
        expect(review).not_to have_key('user_id')
        # rule_id is intentionally present (PR-717 .20: frontend modal
        # needs it for the picker scope after a triage mutation,
        # otherwise it has to refetch).
        expect(review).to have_key('rule_id')
      end
    end

    it 'includes satisfies and satisfied_by arrays' do
      expect(json).to have_key('satisfies')
      expect(json).to have_key('satisfied_by')
      expect(json['satisfies']).to be_an(Array)
      expect(json['satisfied_by']).to be_an(Array)
    end

    it 'excludes type and deleted_at (internal STI/soft-delete fields)' do
      expect(json).not_to have_key('type')
      expect(json).not_to have_key('deleted_at')
    end

    it 'generates zero N+1 queries when rule is properly eager-loaded' do
      loaded_rule = Rule.eager_load(
        :reviews, :disa_rule_descriptions, :rule_descriptions, :checks,
        :additional_answers, { satisfies: :srg_rule }, { satisfied_by: :srg_rule },
        { srg_rule: %i[disa_rule_descriptions rule_descriptions checks security_requirements_guide] }
      ).find(rule.id)

      srg_queries = []
      callback = lambda { |_name, _start, _finish, _id, payload|
        sql = payload[:sql]
        srg_queries << sql if sql.include?('security_requirements_guides') && sql.exclude?('SCHEMA')
      }

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        RuleBlueprint.render_as_json(loaded_rule, view: :editor)
      end

      expect(srg_queries).to be_empty,
                             "Expected 0 SRG queries, got #{srg_queries.length}"
    end
  end

  describe ':navigator view' do
    let(:json) { RuleBlueprint.render_as_json(rule, view: :navigator) }

    it 'includes only sidebar-needed fields' do
      %w[id rule_id title version status rule_severity locked
         review_requestor_id changes_requested].each do |field|
        expect(json).to have_key(field), "Missing navigator field: #{field}"
      end
    end

    it 'excludes heavy fields not needed for sidebar' do
      %w[inspec_control_body inspec_control_file fixtext
         vendor_comments artifact_description].each do |field|
        expect(json).not_to have_key(field), "Navigator should not include: #{field}"
      end
    end

    it 'excludes nested associations' do
      expect(json).not_to have_key('reviews')
      expect(json).not_to have_key('rule_descriptions_attributes')
      expect(json).not_to have_key('disa_rule_descriptions_attributes')
      expect(json).not_to have_key('checks_attributes')
    end
  end

  # comment_summary is the per-rule navigator + section-icon badge
  # driver. Replies count as comments. `open` = non-adjudicated
  # parents + replies under those open parents. Verified at the
  # blueprint layer because the Vue navigator reads only this field.
  describe 'comment_summary (replies count as comments)' do
    let_it_be(:commenter) do
      u = create(:user)
      Membership.find_or_create_by!(user: u, membership: component.project) { |m| m.role = 'viewer' }
      u
    end

    it 'counts replies in total' do
      parent = create(:review, :comment, user: commenter, rule: rule, comment: 'parent')
      create(:review, :comment, user: commenter, rule: rule, comment: 'reply 1',
                                responding_to_review_id: parent.id)
      create(:review, :comment, user: commenter, rule: rule, comment: 'reply 2',
                                responding_to_review_id: parent.id)
      json = RuleBlueprint.render_as_json(rule.reload, view: :editor)
      expect(json['comment_summary']).to include('total' => 3)
    end

    it 'rolls replies of an open parent into the open count' do
      open_parent = create(:review, :comment, user: commenter, rule: rule, comment: 'open parent')
      create(:review, :comment, user: commenter, rule: rule, comment: 'reply',
                                responding_to_review_id: open_parent.id)
      json = RuleBlueprint.render_as_json(rule.reload, view: :editor)
      # 1 open parent + 1 reply = 2 open interactions
      expect(json['comment_summary']).to include('open' => 2, 'total' => 2)
    end

    # "Needs clarification" / "concur" without adjudicate keep the
    # parent in the open set — the conversation is not yet closed.
    it 'counts triaged-but-not-adjudicated parents as open' do
      parent = create(:review, :comment, :needs_clarification, user: commenter, rule: rule, comment: 'needs more info')
      create(:review, :comment, user: commenter, rule: rule, comment: 'reply',
                                responding_to_review_id: parent.id)
      json = RuleBlueprint.render_as_json(rule.reload, view: :editor)
      expect(json['comment_summary']).to include('open' => 2, 'total' => 2)
    end

    it 'walks transitively for reply-of-reply chains' do
      parent = create(:review, :comment, user: commenter, rule: rule, comment: 'parent')
      reply = create(:review, :comment, user: commenter, rule: rule, comment: 'reply',
                                        responding_to_review_id: parent.id)
      create(:review, :comment, user: commenter, rule: rule, comment: 'reply-of-reply',
                                responding_to_review_id: reply.id)
      json = RuleBlueprint.render_as_json(rule.reload, view: :editor)
      expect(json['comment_summary']).to include('open' => 3, 'total' => 3)
    end

    it 'does NOT count replies whose parent has been adjudicated' do
      adjudicated = create(:review, :comment, :concur, :adjudicated, user: commenter, rule: rule, comment: 'closed')
      create(:review, :comment, user: commenter, rule: rule, comment: 'late reply',
                                responding_to_review_id: adjudicated.id)
      json = RuleBlueprint.render_as_json(rule.reload, view: :editor)
      expect(json['comment_summary']).to include('open' => 0, 'total' => 2)
    end
  end

  describe 'collection rendering' do
    it 'renders an array of rules' do
      rules = component.rules.eager_load(
        :reviews, :disa_rule_descriptions, :checks,
        srg_rule: :security_requirements_guide
      ).limit(5).to_a

      result = RuleBlueprint.render_as_json(rules, view: :navigator)

      expect(result).to be_an(Array)
      expect(result.length).to eq(5)
      expect(result.first).to have_key('id')
    end
  end
end
