# frozen_string_literal: true

require 'rails_helper'

##
# Rule#as_json Performance Tests
#
# REQUIREMENT: Rule#as_json must NOT fire individual queries for
# SecurityRequirementsGuide. A component with 200 rules must not
# generate 200 separate SRG queries — the SRG version is the same
# for all rules in a component.
#
# The old code did:
#   SecurityRequirementsGuide.find_by(id: srg_rule&.security_requirements_guide_id)&.version
# which loaded the FULL SRG record (including multi-MB xml) per rule.
#
RSpec.describe 'Rule#as_json performance' do
  # Use real models to test actual query behavior
  let_it_be(:srg) do
    srg_xml = Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read
    parsed = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed)
    srg.xml = srg_xml
    srg.save!
    srg
  end
  let_it_be(:component) { create(:component, based_on: srg) }

  describe 'srg_info.version' do
    it 'returns the correct SRG version' do
      rule = component.rules.eager_load(srg_rule: :security_requirements_guide).first
      json = RuleBlueprint.render_as_hash(rule, view: :editor)

      expect(json[:srg_info]).to be_present
      expect(json[:srg_info][:version]).to eq(srg.version)
    end

    it 'does NOT query SecurityRequirementsGuide table during as_json' do
      # Eager-load the rule with its associations as the controller does
      rule = component.rules.eager_load(
        :reviews, :disa_rule_descriptions, :checks,
        :additional_answers, :satisfies, :satisfied_by,
        srg_rule: :security_requirements_guide
      ).first

      # Count queries during as_json — should be 0 for SRG
      srg_queries = []
      callback = lambda { |_name, _start, _finish, _id, payload|
        sql = payload[:sql]
        srg_queries << sql if sql.include?('security_requirements_guides') && sql.exclude?('SCHEMA')
      }

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        rule.as_json
      end

      expect(srg_queries).to be_empty,
                             "Expected 0 SRG queries during as_json, got #{srg_queries.length}:\n#{srg_queries.join("\n")}"
    end

    it 'does NOT query SRG table when serializing a collection of rules' do
      # Force-load the rules (and all eager-loaded associations) BEFORE measuring.
      # We want to count only queries fired by as_json, not by the initial load.
      rules = component.rules.eager_load(
        :reviews, :disa_rule_descriptions, :checks,
        :additional_answers, :satisfies, :satisfied_by,
        srg_rule: :security_requirements_guide
      ).limit(10).to_a

      srg_queries = []
      callback = lambda { |_name, _start, _finish, _id, payload|
        sql = payload[:sql]
        srg_queries << sql if sql.include?('security_requirements_guides') && sql.exclude?('SCHEMA')
      }

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        rules.map(&:as_json)
      end

      expect(srg_queries).to be_empty,
                             "Expected 0 SRG queries for #{rules.length} rules, got #{srg_queries.length}"
    end

    it 'handles rules without an srg_rule gracefully' do
      rule = component.rules.first
      allow(rule).to receive(:srg_rule).and_return(nil)

      json = RuleBlueprint.render_as_hash(rule, view: :editor)
      expect(json[:srg_info]).to eq({ version: nil })
    end
  end
end
