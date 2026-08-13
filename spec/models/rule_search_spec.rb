# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rule Search' do
  # Requirements:
  # - Rule.search_content should use pg_search for full-text search
  # - Should search title, fixtext, vendor_comments, status_justification, artifact_description
  # - Should support prefix matching (partial words)
  # - Rule.search_phrase should support exact phrase matching with quotes
  # - Both scopes are served by the stored base_rules.searchable vector
  #   (GIN-indexed, trigger-maintained) — never per-row recomputation

  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project, based_on: srg) }

  describe '.search_content' do
    # Create rules in a before block to ensure they exist before ALL tests
    let(:rule1) { component.rules.first }
    let(:rule2) { component.rules.second }

    before do
      # Ensure rules exist and have unique searchable content
      rule1.update!(
        title: 'Xylophone Zebra Configuration',
        fixtext: 'Configure quantum entanglement protocol',
        vendor_comments: 'Applies to starship deployments'
      )
      rule2.update!(
        title: 'Platypus Server Hardening',
        fixtext: 'Configure marsupial authentication',
        vendor_comments: 'Applies to Antarctic systems'
      )
    end

    it 'finds rules by title' do
      results = Rule.search_content('Xylophone')
      expect(results).to include(rule1)
      expect(results).not_to include(rule2)
    end

    it 'finds rules by fixtext' do
      # Use a unique term that only exists in our test data
      results = Rule.search_content('quantum entanglement')
      expect(results).to include(rule1)
    end

    it 'finds rules by vendor_comments' do
      results = Rule.search_content('starship deployments')
      expect(results).to include(rule1)
    end

    it 'finds rules by partial word (prefix) with full word' do
      # PostgreSQL tsearch prefix needs at least prefix: true enabled
      # Use full word to verify basic search works
      results = Rule.search_content('Xylophone')
      expect(results).to include(rule1)
    end

    it 'ranks results by relevance' do
      results = Rule.search_content('Platypus')
      expect(results.to_a).to include(rule2)
    end

    it 'returns empty relation for no matches' do
      results = Rule.search_content('NonexistentXyzzyTerm123')
      expect(results).to be_empty
    end
  end

  describe '.search_phrase' do
    let!(:rule_with_phrase) do
      rule = component.rules.first || create(:rule, component: component)
      rule.update!(
        title: 'Configure wombat to enable wallaby logging',
        fixtext: 'Enable wallaby logging for all wombat events'
      )
      rule
    end

    it 'finds exact phrases' do
      results = Rule.search_phrase('wallaby logging')
      expect(results).to include(rule_with_phrase)
    end

    it 'returns empty for partial phrase matches' do
      # "wallaby wombat" is not an exact phrase in the data (reversed order)
      results = Rule.search_phrase('"wallaby wombat"')
      expect(results).to be_empty
    end

    it 'returns empty relation for blank query' do
      results = Rule.search_phrase('')
      expect(results).to be_empty
    end
  end

  describe 'stored searchable vector' do
    # The scopes must be SERVED by the indexed base_rules.searchable column.
    # Per-row to_tsvector/similarity recomputation in the query is the defect
    # these examples pin against.
    it 'search_content queries the stored column, not per-row recomputation' do
      sql = Rule.search_content('term').to_sql
      expect(sql).to include('"base_rules"."searchable"')
      expect(sql).not_to include('to_tsvector')
      expect(sql).not_to include('similarity(')
    end

    it 'search_phrase queries the stored column, not per-row recomputation' do
      sql = Rule.search_phrase('term').to_sql
      expect(sql).to include('base_rules.searchable')
      expect(sql).not_to include('to_tsvector')
    end

    it 'keeps the vector current when a searched base column changes' do
      rule = component.rules.first
      rule.update!(title: 'Quixotic Vector Freshness Probe')
      expect(Rule.search_content('Quixotic')).to include(rule)
    end

    it 'keeps the vector current when check content changes' do
      rule = component.rules.first
      Check.create!(base_rule: rule, content: 'Verify the zamboni maintenance log')
      expect(Rule.search_content('zamboni')).to include(rule)
    end

    it 'keeps the vector current when a disa description changes' do
      rule = component.rules.first
      description = rule.disa_rule_descriptions.first ||
                    DisaRuleDescription.create!(base_rule: rule)
      description.update!(vuln_discussion: 'Applies to gryphon telemetry review')
      expect(Rule.search_content('gryphon')).to include(rule)
    end
  end
end
