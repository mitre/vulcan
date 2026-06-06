# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component do
  include_context 'components model base setup'

  context 'component creation' do
    it 'can duplicate a component under the same project' do
      components_component.rules.update(locked: true)
      components_component.reload
      components_component.update(released: true)

      p1_c2 = components_component.duplicate(new_name: 'Photon OS 3', new_version: 1, new_release: 2, new_title: 'title',
                                             new_description: 'desc')
      # should have the same number of rules
      expect(components_component.rules.size).to eq(p1_c2.rules.size)
      # should still belong to the same SRG
      expect(components_component.security_requirements_guide_id).to eq(p1_c2.security_requirements_guide_id)
      # should still belong to the same project
      expect(components_component.project_id).to eq(p1_c2.project_id)
      # should not be released
      expect(p1_c2.released).to be(false)
      # should have the new name
      expect(p1_c2.name).to eq('Photon OS 3')
      # should have the new version
      expect(p1_c2.version).to eq(1)
      # should have the new release
      expect(p1_c2.release).to eq(2)
      # should have the new title
      expect(p1_c2.title).to eq('title')
      # should have the new description
      expect(p1_c2.description).to eq('desc')
    end

    it 'can create a new component from a base SRG' do
      # The creation of p1_c1 in the setup should alread have these rules created
      components_component.reload
      expect(components_component.rules.size).to eq(components_srg.srg_rules.size)
    end

    it 'amoeba re-links additional_answers to the new component rules' do
      orig_rule = components_component.rules.first
      question = AdditionalQuestion.create!(component: components_component, name: 'Test Q',
                                            question_type: 'freeform')
      AdditionalAnswer.create!(additional_question: question, rule: orig_rule, answer: 'test answer')

      dup = components_component.duplicate(new_version: 94, new_release: 1)
      dup.save!

      dup_question = dup.additional_questions.find_by(name: 'Test Q')
      expect(dup_question).to be_present
      dup_answer = dup_question.additional_answers.first
      expect(dup_answer.rule.component_id).to eq(dup.id)
      expect(dup_answer.rule.rule_id).to eq(orig_rule.rule_id)

      dup.destroy!
    end

    it 'amoeba duplicated rules belong to the new component, not the original' do
      dup = components_component.duplicate(new_version: 95, new_release: 1)
      dup.save!

      dup.rules.each do |dup_rule|
        expect(dup_rule.component_id).to eq(dup.id)
      end
      expect(dup.rules.pluck(:component_id).uniq).to eq([dup.id])

      dup.destroy!
    end
  end

  # ─── B8 Regression: Duplicated component rules_count ─────
  # REQUIREMENT: When a component is duplicated, the new component's
  # rules_count must equal the actual number of rules, NOT accumulate
  # from the original's counter_cache value + new rule inserts.
  describe '#duplicate rules_count (B8 regression)' do
    it 'duplicated component has correct rules_count after save' do
      original = components_component
      original_count = original.rules.where(deleted_at: nil).count
      expect(original_count).to be > 0

      dup = original.duplicate(new_version: 99, new_release: 99)
      dup.save!
      dup.reload

      # Without counter reset, rules_count may be double the actual count
      actual_count = dup.rules.where(deleted_at: nil).count
      expect(dup.rules_count).to eq(actual_count),
                                 "rules_count (#{dup.rules_count}) should equal actual count (#{actual_count}), " \
                                 "not #{original_count * 2} (counter_cache accumulation bug)"

      dup.destroy!
    end

    it 'duplicate_reviews_and_history copies without error' do
      original = components_component
      dup = original.duplicate(new_version: 98, new_release: 98)
      dup.save!

      # This was raising TypeError (Rails 8 bind params) and
      # NoMethodError (sanitize_sql_array as instance method)
      expect { dup.duplicate_reviews_and_history(original.id) }.not_to raise_error

      dup.destroy!
    end

    # Regression: the raw-SQL copy bypasses sync_commentable_from_rule, so it
    # must dual-write commentable_*. Without them the copied comment is counted
    # but never listed in the triage view (paginated_comments filters commentable).
    it 'duplicate_reviews_and_history dual-writes commentable on copied reviews' do
      original = components_component
      commenter = Membership.find_or_create_by!(user: create(:user), membership: original.project) do |m|
        m.role = 'viewer'
      end.user
      Review.create!(rule: original.rules.first, user: commenter, action: 'comment', comment: 'orig comment')

      dup = original.duplicate(new_version: 96, new_release: 96)
      dup.save!
      dup.duplicate_reviews_and_history(original.id)

      copied = Review.where(rule_id: dup.rules.pluck(:id), comment: 'orig comment').first
      expect(copied).to be_present
      expect(copied.commentable_type).to eq('BaseRule')
      expect(copied.commentable_id).to eq(copied.rule_id)
      expect(dup.paginated_comments[:rows].pluck(:id)).to include(copied.id)

      dup.destroy!
    end

    it 'auditing can be suppressed during save for performance' do
      original = components_component
      dup = original.duplicate(new_version: 97, new_release: 97)

      # Controller suppresses auditing during dup save — verify the
      # mechanism works at model level
      Component.without_auditing { Rule.without_auditing { dup.save! } }

      rule_audits = Audited::Audit.where(
        auditable_type: 'BaseRule',
        auditable_id: dup.rules.pluck(:id)
      ).count
      expect(rule_audits).to eq(0),
                             "Expected 0 rule audits with auditing disabled, got #{rule_audits}"

      dup.destroy!
    end
  end

  describe '#overlay' do
    before do
      components_component.rules.update_all(locked: true)
      components_component.update!(released: true)
    end

    it 'returns unpersisted component with correct project_id and component_id' do
      other_project = create(:project)
      overlaid = components_component.overlay(other_project.id)

      expect(overlaid.project_id).to eq(other_project.id)
      expect(overlaid.component_id).to eq(components_component.id)
      expect(overlaid).not_to be_persisted
    end

    it 'copies rules from the parent component' do
      other_project = create(:project)
      overlaid = components_component.overlay(other_project.id)
      expect(overlaid.rules.size).to eq(components_component.rules.size)
    end

    it 'fails validation when parent component is not released' do
      components_component.update_columns(released: false)
      other_project = create(:project)
      overlaid = components_component.overlay(other_project.id)
      expect(overlaid).not_to be_valid
      expect(overlaid.errors[:base].join).to match(/not been released/i)
    end
  end

  describe '#duplicate with new_srg_id' do
    let_it_be(:new_srg) do
      srg_xml = Rails.root.join('db/seeds/srgs/U_Web_Server_SRG_V4R4_Manual-xccdf.xml').read
      parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
      srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
      srg.xml = srg_xml
      srg.save!
      srg
    end

    it 'preserves AC rules and updates their srg_rule association' do
      ac_rule = components_component.rules.first
      ac_rule.update!(status: 'Applicable - Configurable')
      original_title = ac_rule.title

      dup = components_component.duplicate(new_version: 50, new_release: 1, new_srg_id: new_srg.id)
      matching = dup.rules.find_by(version: ac_rule.version)

      expect(matching).to be_present
      expect(matching.status).to eq('Applicable - Configurable')
      expect(matching.title).to eq(original_title)

      dup.destroy! if dup.persisted?
    end

    it 'skips SRG migration when new SRG matches current SRG' do
      original_srg_id = components_component.security_requirements_guide_id
      dup = components_component.duplicate(
        new_version: 51, new_release: 1,
        new_srg_id: original_srg_id
      )
      expect(dup.security_requirements_guide_id).to eq(original_srg_id)
      expect(dup).not_to be_persisted

      dup.destroy! if dup.persisted?
    end
  end

  describe '#import_srg_rules failure path' do
    it 'raises RecordInvalid when from_mapping returns false' do
      allow_any_instance_of(Component).to receive(:from_mapping).and_return(false)

      expect do
        Component.create!(
          project: components_project, name: 'Fail Import', title: 'Fail',
          version: 'V1R1', prefix: 'FAIL-01', based_on: components_srg
        )
      end.to raise_error(ActiveRecord::RecordInvalid)

      expect(Component.find_by(prefix: 'FAIL-01')).to be_nil
    end
  end
end
