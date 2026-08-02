# frozen_string_literal: true

require 'rails_helper'

# "Which SRG requirement does this requirement correspond to?" is a domain
# question with a different answer per document kind, and it was answered
# independently in three serializers:
#
#   RuleBlueprint            rule.srg_rule&.version
#   SatisfactionBlueprint    rule.srg_rule&.version
#   AuthoredSrgRuleBlueprint rule.version
#
# Three copies of one rule, kept in agreement only by nobody having edited
# them apart yet — and the front end then re-derived it a fourth time,
# sorting on the rule's OWN version while displaying the served value.
#
# The STI hierarchy already models the kind difference, so the answer belongs
# there once, as a polymorphic method every consumer reads.
RSpec.describe 'requirement SRG identifier' do
  describe Rule do
    it 'answers with the SOURCE SRG requirement version, not the rule\'s own version' do
      rule = create(:rule)

      # Guard the fixture: the two values must actually differ, or this test
      # would pass against either implementation and prove nothing.
      expect(rule.version).not_to eq(rule.srg_rule.version)

      expect(rule.srg_identifier).to eq(rule.srg_rule.version)
    end

    it 'is nil when no source SRG requirement is present, never a fabricated value' do
      rule = create(:rule)
      rule.srg_rule = nil

      expect(rule.srg_identifier).to be_nil
    end
  end

  describe SrgRule do
    it 'answers with its own version — an authored requirement IS the SRG requirement' do
      authored = create(:srg_rule, :authored, version: 'SRG-APP-000123')

      expect(authored.srg_identifier).to eq('SRG-APP-000123')
    end
  end

  describe BaseRule do
    it 'refuses to answer on the base, so a kind that forgets to override fails loudly' do
      # Asserting only that the method is DEFINED would pass against a base
      # that silently returns nil — the exact failure this contract exists to
      # prevent, since a nil identifier looks like "no corresponding SRG
      # requirement" rather than "this kind never implemented the answer".
      expect { BaseRule.new.srg_identifier }
        .to raise_error(NotImplementedError, /must answer srg_identifier/)
    end
  end
end
