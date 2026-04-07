# frozen_string_literal: true

require 'rails_helper'

##
# Leaf Blueprint Tests
#
# REQUIREMENT: Each leaf blueprint must produce output that matches the current
# as_json output shape, including the `_destroy: false` key that Rails
# accepts_nested_attributes_for expects. This ensures Vue components that
# consume this data continue to work without changes.
#
RSpec.describe 'Leaf Blueprints' do
  let_it_be(:srg) do
    srg_xml = Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read
    parsed = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed)
    srg.xml = srg_xml
    srg.save!
    srg
  end
  let_it_be(:component) { create(:component, based_on: srg) }
  let_it_be(:rule) { component.rules.first }

  describe CheckBlueprint do
    let(:check) { rule.checks.first }

    it 'includes all expected fields' do
      json = CheckBlueprint.render_as_hash(check)

      expect(json).to have_key(:id)
      expect(json).to have_key(:system)
      expect(json).to have_key(:content_ref_name)
      expect(json).to have_key(:content_ref_href)
      expect(json).to have_key(:content)
      expect(json).to have_key(:_destroy)
      expect(json[:_destroy]).to be false
    end

    it 'excludes timestamps and foreign keys' do
      json = CheckBlueprint.render_as_hash(check)

      expect(json).not_to have_key(:created_at)
      expect(json).not_to have_key(:updated_at)
      expect(json).not_to have_key(:base_rule_id)
    end

    it 'matches the shape of the current as_json output' do
      blueprint_output = CheckBlueprint.render_as_hash(check)
      legacy_output = check.as_json.merge(_destroy: false).symbolize_keys
      legacy_output = legacy_output.except(:created_at, :updated_at, :base_rule_id)

      expect(blueprint_output.keys.sort).to eq(legacy_output.keys.sort)
    end
  end

  describe DisaRuleDescriptionBlueprint do
    let(:drd) { rule.disa_rule_descriptions.first }

    it 'includes all expected fields' do
      json = DisaRuleDescriptionBlueprint.render_as_hash(drd)

      expect(json).to have_key(:id)
      expect(json).to have_key(:vuln_discussion)
      expect(json).to have_key(:mitigations)
      expect(json).to have_key(:documentable)
      expect(json).to have_key(:severity_override_guidance)
      expect(json).to have_key(:_destroy)
    end

    it 'excludes timestamps and foreign keys' do
      json = DisaRuleDescriptionBlueprint.render_as_hash(drd)

      expect(json).not_to have_key(:created_at)
      expect(json).not_to have_key(:updated_at)
      expect(json).not_to have_key(:base_rule_id)
    end
  end

  describe RuleDescriptionBlueprint do
    let(:rd) do
      rule.rule_descriptions.first ||
        RuleDescription.create!(base_rule: rule, description: 'Test description')
    end

    it 'includes all expected fields' do
      json = RuleDescriptionBlueprint.render_as_hash(rd)

      expect(json).to have_key(:id)
      expect(json).to have_key(:description)
      expect(json).to have_key(:_destroy)
    end

    it 'excludes timestamps and foreign keys' do
      json = RuleDescriptionBlueprint.render_as_hash(rd)

      expect(json).not_to have_key(:created_at)
      expect(json).not_to have_key(:updated_at)
      expect(json).not_to have_key(:base_rule_id)
    end
  end

  describe AdditionalAnswerBlueprint do
    let_it_be(:question) do
      AdditionalQuestion.find_or_create_by!(
        name: 'Test Question',
        component: component,
        question_type: 'freeform'
      )
    end
    let_it_be(:answer) do
      AdditionalAnswer.find_or_create_by!(
        additional_question: question,
        rule: rule,
        answer: 'Test answer content'
      )
    end

    it 'includes expected fields' do
      json = AdditionalAnswerBlueprint.render_as_hash(answer)

      expect(json).to have_key(:id)
      expect(json).to have_key(:additional_question_id)
      expect(json).to have_key(:answer)
    end

    it 'excludes rule_id and timestamps (matches current as_json.except pattern)' do
      json = AdditionalAnswerBlueprint.render_as_hash(answer)

      expect(json).not_to have_key(:rule_id)
      expect(json).not_to have_key(:created_at)
      expect(json).not_to have_key(:updated_at)
    end
  end
end
