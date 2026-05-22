# frozen_string_literal: true

require 'rails_helper'

# Phase 1 of the DB 3NF redesign (docs/plans/DATABASE-COMPLETE-REDESIGN-v2.md).
# DisplayFallback establishes the "prefer the rule's own value, fall back to the
# SRG template" pattern WITHOUT changing the schema. This lets later phases null
# out duplicated content on rules and rely on the SRG template transparently.
RSpec.describe DisplayFallback do
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:srg_rule) do
    create(:srg_rule,
           security_requirements_guide: srg,
           title: 'SRG template title',
           fixtext: 'SRG template fixtext',
           ident: 'CCI-999999',
           rule_severity: 'high')
  end
  let_it_be(:component) { create(:component, :skip_rules, based_on: srg) }

  def build_rule(**attrs)
    create(:rule, component: component, srg_rule: srg_rule, **attrs)
  end

  describe '#display_title' do
    it 'returns the rule\'s own title when present' do
      rule = build_rule(title: 'My custom title')
      expect(rule.display_title).to eq('My custom title')
    end

    it 'falls back to the SRG template title when the rule\'s title is blank' do
      rule = build_rule(title: 'placeholder')
      rule.update_column(:title, nil)
      expect(rule.reload.display_title).to eq('SRG template title')
    end

    it 'falls back when the rule\'s title is an empty string' do
      rule = build_rule(title: 'placeholder')
      rule.update_column(:title, '')
      expect(rule.reload.display_title).to eq('SRG template title')
    end
  end

  describe '#display_fixtext' do
    it 'returns the rule\'s own fixtext when present' do
      rule = build_rule(fixtext: 'My fix')
      expect(rule.display_fixtext).to eq('My fix')
    end

    it 'falls back to the SRG template fixtext when blank' do
      rule = build_rule
      rule.update_column(:fixtext, nil)
      expect(rule.reload.display_fixtext).to eq('SRG template fixtext')
    end
  end

  describe '#display_field' do
    it 'returns the rule\'s own value when present' do
      rule = build_rule(ident: 'CCI-000001')
      expect(rule.display_field(:ident)).to eq('CCI-000001')
    end

    it 'falls back to the SRG template value when the rule value is blank' do
      rule = build_rule
      rule.update_column(:ident, nil)
      expect(rule.reload.display_field(:ident)).to eq('CCI-999999')
    end

    it 'does not raise for a field the SRG template does not respond to' do
      rule = build_rule
      rule.update_column(:title, nil)
      expect { rule.reload.display_field(:nonexistent_field) }.not_to raise_error
    end
  end

  describe '#has_overrides?' do
    it 'is false when every overridable field matches the SRG template' do
      rule = build_rule(title: srg_rule.title, fixtext: srg_rule.fixtext,
                        ident: srg_rule.ident, rule_severity: srg_rule.rule_severity)
      expect(rule.has_overrides?).to be(false)
    end

    it 'is true when the title differs from the SRG template' do
      rule = build_rule(title: 'Changed', fixtext: srg_rule.fixtext,
                        ident: srg_rule.ident, rule_severity: srg_rule.rule_severity)
      expect(rule.has_overrides?).to be(true)
    end
  end

  describe '.with_display_fallbacks' do
    it 'eager-loads srg_rule so display methods fire no per-row queries' do
      build_rule(title: 'a')
      build_rule(title: 'b')

      rules = component.rules.with_display_fallbacks.to_a
      # association cache already populated — reading the SRG template adds no queries
      expect(count_queries { rules.each(&:display_title) }).to eq(0)
    end
  end
end
