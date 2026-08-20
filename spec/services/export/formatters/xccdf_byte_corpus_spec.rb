# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT (byte-identical golden master): the 1.1.4 XCCDF export must
# not change by a single byte through the version-profile refactor — or
# any future refactor that does not intend an emission change. The corpus
# fixtures were captured from the pre-refactor formatter and committed;
# this spec rebuilds the same deterministic components (time frozen — the
# emission embeds today's date twice; every sequence-derived value is
# pinned explicitly) and compares output byte-for-byte.
#
# Corpus A: a real component built from the seeded GPOS SRG XML (first 30
# requirements in canonical order — real DISA content).
# Corpus B: a hand-built edge component — a satisfies pair (satisfaction
# text embedded in VulnDiscussion) and a nil-discussion rule (the frozen
# '' fallback path).
#
# To regenerate INTENTIONALLY (an approved emission change only):
#   REGENERATE_XCCDF_CORPUS=1 bundle exec rspec \
#     spec/services/export/formatters/xccdf_byte_corpus_spec.rb
# then review the fixture diff like production code.
# ==========================================================================
RSpec.describe 'XCCDF 1.1.4 byte-identical corpus' do
  include ActiveSupport::Testing::TimeHelpers

  let(:formatter) { Export::Formatters::XccdfFormatter.new }

  def fixture_path(name)
    Rails.root.join('spec/fixtures/xccdf', name)
  end

  def corpus_date
    Time.zone.local(2026, 7, 26, 12, 0, 0)
  end

  # Real content: the full GPOS import (factory default), explicit
  # component identity so no factory sequence reaches the emission.
  def corpus_a_component
    create(:component,
           name: 'Corpus GPOS Component', prefix: 'CORP-00',
           title: 'Corpus A — real GPOS content', description: 'Byte corpus A',
           version: 3, release: 3,
           based_on: create(:security_requirements_guide))
  end

  def corpus_a_rules(component)
    component.rules.eager_load(:disa_rule_descriptions, :checks, :satisfies, :satisfied_by,
                               srg_rule: %i[disa_rule_descriptions rule_descriptions checks])
             .order(:rule_id).limit(30)
  end

  # Edge shapes: satisfaction text (which embeds the satisfied rules'
  # catalog SRG versions — pinned explicitly) and a nil vuln_discussion.
  def corpus_b_component
    srg = create(:security_requirements_guide, :skip_rules)
    catalog_one = create(:srg_rule, security_requirements_guide: srg, version: 'SRG-OS-000777')
    catalog_two = create(:srg_rule, security_requirements_guide: srg, version: 'SRG-OS-000778')
    component = create(:component, :skip_rules,
                       name: 'Corpus Edge Component', prefix: 'CORB-00',
                       title: 'Corpus B — satisfies and nil discussion', description: 'Byte corpus B',
                       version: 1, release: 2, based_on: srg)
    satisfier = create(:rule, component: component, srg_rule: catalog_one, rule_id: '000001',
                              title: 'Edge satisfier', rule_severity: 'medium', rule_weight: '10.0',
                              version: 'CORB-01', fixtext: 'Edge fix one', ident: 'CCI-000366')
    satisfied = create(:rule, component: component, srg_rule: catalog_two, rule_id: '000002',
                              title: 'Edge satisfied', rule_severity: 'high', rule_weight: '10.0',
                              version: 'CORB-02', fixtext: 'Edge fix two', ident: 'CCI-000366')
    satisfier.satisfies << satisfied
    # The nil-discussion edge: the frozen-'' fallback append path.
    satisfier.disa_rule_descriptions.first.update_column(:vuln_discussion, nil)
    satisfied.disa_rule_descriptions.first.update_column(:vuln_discussion, 'Edge discussion text')
    component
  end

  def corpus_b_rules(component)
    component.rules.eager_load(:disa_rule_descriptions, :checks, :satisfies, :satisfied_by)
             .order(:rule_id)
  end

  def generate(component, rules)
    travel_to(corpus_date) do
      formatter.generate_from_component(component: component, rules: rules)
    end
  end

  # Regenerate mode rewrites the fixture from current output (the
  # comparison below then passes against the fresh bytes) — review the
  # fixture diff like production code before committing it.
  def regenerate_fixture(path, xml)
    return unless ENV['REGENERATE_XCCDF_CORPUS']

    FileUtils.mkdir_p(path.dirname)
    File.binwrite(path, xml)
  end

  it 'emits corpus A (real GPOS content) byte-identical to the committed fixture' do
    component = corpus_a_component
    xml = generate(component, corpus_a_rules(component))
    regenerate_fixture(fixture_path('corpus_a_gpos.xml'), xml)

    # Binary-exact on purpose: byte-identical means bytes, not
    # encoding-normalized strings.
    expect(xml.b).to eq(File.binread(fixture_path('corpus_a_gpos.xml')))
  end

  it 'emits corpus B (satisfies + nil discussion edges) byte-identical to the committed fixture' do
    component = corpus_b_component
    xml = generate(component, corpus_b_rules(component))
    regenerate_fixture(fixture_path('corpus_b_edges.xml'), xml)

    expect(xml.b).to eq(File.binread(fixture_path('corpus_b_edges.xml')))
  end
end
