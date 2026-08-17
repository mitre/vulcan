# frozen_string_literal: true

require 'rails_helper'

##
# AuthoredSrgRuleBlueprint Tests
#
# REQUIREMENT: component-authored SRG requirements share BaseRuleBlueprint's
# surface with RuleBlueprint but serve only the authored-kind keys. This spec
# pins the inheritance and the byte-identity-critical field ORDER
# (derived_from_version sits between srg_id and the shared content attributes),
# so a future edit to the base or to the :content_attributes composition cannot
# silently reshape the authored payload. Shape parity across kinds is also
# covered by spec/requests/rules_editor_payload_spec.rb.
#
RSpec.describe 'AuthoredSrgRuleBlueprint' do
  let_it_be(:project) { create(:project) }
  let_it_be(:srg_component) do
    create(:component, :skip_rules, project: project, document_type: 'srg')
  end
  let_it_be(:authored) { create(:srg_rule, :authored, component: srg_component) }

  it 'inherits the shared surface from BaseRuleBlueprint' do
    expect(AuthoredSrgRuleBlueprint.ancestors).to include(BaseRuleBlueprint)
  end

  describe ':editor view' do
    let(:json) { AuthoredSrgRuleBlueprint.render_as_json(authored, view: :editor) }

    it 'renders the shared base surface (default fields + comment summary + srg_id)' do
      %w[id rule_id title version status rule_severity locked review_requestor_id
         changes_requested comment_summary nist_control_family srg_id].each do |field|
        expect(json).to have_key(field), "Missing shared field: #{field}"
      end
    end

    it 'includes the content attributes and collaboration keys' do
      expect(json).to have_key('disa_rule_descriptions_attributes')
      expect(json).to have_key('checks_attributes')
      expect(json).to have_key('rule_descriptions_attributes')
      expect(json).to have_key('reviews')
      expect(json['reviews']).to be_an(Array)
    end

    it 'includes derived_from_version and omits every Rule-only key' do
      expect(json).to have_key('derived_from_version')
      expect(json).not_to have_key('satisfies')
      expect(json).not_to have_key('satisfied_by')
      expect(json).not_to have_key('srg_info')
      expect(json).not_to have_key('srg_rule_attributes')
      expect(json).not_to have_key('additional_answers_attributes')
      expect(json).not_to have_key('inspec_control_body')
    end

    # The audit trail is opt-in for the same reason as RuleBlueprint: it cannot
    # be batched and is shown for one requirement at a time.
    it 'omits histories unless asked, and includes it when requested' do
      expect(json).not_to have_key('histories')

      requested = AuthoredSrgRuleBlueprint.render_as_json(authored, view: :editor, include_histories: true)
      expect(requested).to have_key('histories')
      expect(requested['histories']).to be_an(Array)
    end
  end

  describe ':viewer field order (byte-identity guard)' do
    it 'places derived_from_version between srg_id and the shared content attributes' do
      keys = AuthoredSrgRuleBlueprint.render_as_json(authored, view: :viewer).keys
      expect(keys.index('srg_id')).to eq(keys.index('derived_from_version') - 1)
      expect(keys.index('derived_from_version')).to eq(keys.index('disa_rule_descriptions_attributes') - 1)
      expect(keys.index('disa_rule_descriptions_attributes')).to eq(keys.index('checks_attributes') - 1)
      expect(keys.index('checks_attributes')).to be < keys.index('rule_descriptions_attributes')
    end
  end

  describe 'navigator and picker views' do
    it 'render only the shared head, omitting content and Rule-only keys' do
      %i[navigator picker].each do |view|
        keys = AuthoredSrgRuleBlueprint.render_as_json(authored, view: view).keys
        expect(keys).to include('id', 'rule_id', 'status', 'comment_summary')
        expect(keys).not_to include('disa_rule_descriptions_attributes', 'checks_attributes',
                                    'satisfies', 'satisfied_by',
                                    'derived_from_version', 'rule_descriptions_attributes'),
                            "#{view} view leaked a non-head key"
      end
    end
  end
end
