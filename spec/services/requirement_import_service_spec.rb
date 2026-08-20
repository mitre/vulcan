# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RequirementImportService do
  # Hand-crafted core parents (skip the XML import) so catalog row counts
  # and content are exact and cheap.
  let_it_be(:core_a) { create(:security_requirements_guide, :core, :skip_rules) }
  let_it_be(:core_a_rows) do
    [
      create(:srg_rule, security_requirements_guide: core_a, version: 'SRG-OS-000001',
                        title: 'Limit concurrent sessions',
                        fixtext: 'Configure the OS to limit concurrent sessions.'),
      create(:srg_rule, security_requirements_guide: core_a, version: 'SRG-OS-000002',
                        title: 'Enforce session locks',
                        fixtext: 'Configure the OS to enforce session locks.')
    ]
  end

  let_it_be(:srg_component) do
    create(:component, :skip_rules, document_type: 'srg', based_on: core_a,
                                    prefix: 'TSRG-00', name: 'Authored SRG component')
  end

  describe '#import_parent! (srg kind — the authored generator)' do
    it 'produces authored SrgRules holding the XOR for every generated row' do
      described_class.new(srg_component).import_parent!(core_a)

      rows = srg_component.authored_srg_rules.reload
      expect(rows.size).to eq(2)
      expect(rows).to all(have_attributes(component_id: srg_component.id,
                                          security_requirements_guide_id: nil))
      expect(rows.map(&:derived_from_srg_rule_id)).to match_array(core_a_rows.map(&:id))
    end

    it 'numbers generated rows with local ordinals — the catalog document id never carries over' do
      described_class.new(srg_component).import_parent!(core_a)

      rows = srg_component.authored_srg_rules.reload.order(:rule_id)
      expect(rows.map(&:rule_id)).to eq(%w[000001 000002])
      expect(core_a_rows.map(&:rule_id)).to all(match(/\ASV-/))
    end

    it 'numbers deterministically in the source document order, not insertion or database order' do
      reversed_core = create(:security_requirements_guide, :core, :skip_rules)
      create(:srg_rule, security_requirements_guide: reversed_core, version: 'SRG-OS-000902',
                        title: 'Inserted first, numbered second')
      create(:srg_rule, security_requirements_guide: reversed_core, version: 'SRG-OS-000901',
                        title: 'Inserted second, numbered first')
      component = create(:component, :skip_rules, document_type: 'srg', based_on: reversed_core,
                                                  prefix: 'DETO-00', name: 'Deterministic numbering')

      described_class.new(component).import_parent!(reversed_core)

      rows = component.authored_srg_rules.reload.order(:rule_id)
      expect(rows.map { |r| [r.rule_id, r.derived_from.version] }).to eq(
        [%w[000001 SRG-OS-000901], %w[000002 SRG-OS-000902]]
      )
    end

    it 'copies content from the catalog row' do
      described_class.new(srg_component).import_parent!(core_a)

      row = srg_component.authored_srg_rules.find_by(version: 'SRG-OS-000001')
      expect(row.title).to eq('Limit concurrent sessions')
      expect(row.fixtext).to eq('Configure the OS to limit concurrent sessions.')
      expect(row.rule_severity).to eq('medium')
      expect(row.ident).to eq('CCI-000366')
    end

    it 'starts every generated row at Not Yet Determined regardless of catalog status' do
      expect(core_a_rows.map(&:status)).to all(eq('Applicable - Configurable'))

      described_class.new(srg_component).import_parent!(core_a)

      expect(srg_component.authored_srg_rules.pluck(:status)).to all(eq('Not Yet Determined'))
    end

    it 'copies the nested catalog records onto each generated row' do
      catalog_row = core_a_rows.first
      catalog_row.checks.first.update!(content: 'Verify the session limit is configured.')
      catalog_row.disa_rule_descriptions.first.update!(vuln_discussion: 'Unlimited sessions enable DoS.')
      catalog_row.references.create!(title: 'DPMS Target', contributor: 'DISA')

      described_class.new(srg_component).import_parent!(core_a)

      row = srg_component.authored_srg_rules.find_by(version: 'SRG-OS-000001')
      expect(row.checks.pluck(:content)).to eq(['Verify the session limit is configured.'])
      expect(row.disa_rule_descriptions.pluck(:vuln_discussion)).to eq(['Unlimited sessions enable DoS.'])
      expect(row.references.pluck(:title)).to eq(['DPMS Target'])
    end

    it 'builds the initial creation audit for each generated row' do
      described_class.new(srg_component).import_parent!(core_a)

      audits = Audited::Audit.where(auditable_id: srg_component.authored_srg_rules.select(:id),
                                    auditable_type: 'BaseRule', action: 'create')
      expect(audits.count).to eq(2)
      expect(audits.pluck(:user_type)).to all(eq('System'))
    end

    it 'imports only the filtered requirements when versions are given' do
      described_class.new(srg_component).import_parent!(core_a, versions: ['SRG-OS-000002'])

      expect(srg_component.authored_srg_rules.pluck(:version)).to eq(['SRG-OS-000002'])
    end
  end

  describe '#import_all! (srg kind)' do
    let_it_be(:core_b) { create(:security_requirements_guide, :core, :skip_rules) }
    let_it_be(:core_b_row) do
      create(:srg_rule, security_requirements_guide: core_b, version: 'SRG-APP-000101',
                        title: 'Log privileged activity')
    end

    let(:dual_parent_component) do
      create(:component, :skip_rules, document_type: 'srg', based_on: core_a,
                                      prefix: 'TSRG-00', name: 'Dual-parent SRG component').tap do |component|
        component.component_source_srgs.create!(security_requirements_guide: core_b)
      end
    end

    it 'union-imports every requirement of all declared parents by default' do
      described_class.new(dual_parent_component).import_all!

      rows = dual_parent_component.authored_srg_rules.reload
      expect(rows.size).to eq(3)
      by_parent = rows.group_by { |row| row.derived_from.security_requirements_guide_id }
      expect(by_parent[core_a.id].map(&:version)).to match_array(%w[SRG-OS-000001 SRG-OS-000002])
      expect(by_parent[core_b.id].map(&:version)).to eq(['SRG-APP-000101'])
    end

    it 'imports only the selected requirements per parent in selective mode' do
      described_class.new(dual_parent_component)
                     .import_all!(selections: { core_a.id => ['SRG-OS-000001'] })

      expect(dual_parent_component.authored_srg_rules.pluck(:version)).to eq(['SRG-OS-000001'])
    end

    it 'contributes no rows from a declared parent selected down to nothing' do
      described_class.new(dual_parent_component)
                     .import_all!(selections: { core_a.id => [], core_b.id => ['SRG-APP-000101'] })

      expect(dual_parent_component.authored_srg_rules.pluck(:version)).to eq(['SRG-APP-000101'])
    end
  end

  describe '#import_all! (stig kind — same machinery, Rule rows)' do
    # Real XML parents: the stig path runs today's single-SRG import per
    # parent, which parses the benchmark XML.
    let_it_be(:derived_a) { create(:security_requirements_guide) }
    let_it_be(:derived_b) { create(:security_requirements_guide) }

    let(:stig_component) do
      create(:component, :skip_rules, based_on: derived_a,
                                      prefix: 'TSTG-00', name: 'Dual-parent STIG component').tap do |component|
        component.component_source_srgs.create!(security_requirements_guide: derived_b)
      end
    end

    it 'union-imports Rule rows from every declared parent with sequential numbering across parents' do
      described_class.new(stig_component).import_all!

      rules = stig_component.rules.reload
      expect(rules.size).to eq(derived_a.srg_rules.count + derived_b.srg_rules.count)

      # Every imported rule links back to a catalog row of its parent.
      parent_of = SrgRule.where(id: rules.map(&:srg_rule_id))
                         .pluck(:id, :security_requirements_guide_id).to_h
      by_parent = rules.group_by { |rule| parent_of[rule.srg_rule_id] }
      expect(by_parent[derived_a.id].size).to eq(derived_a.srg_rules.count)
      expect(by_parent[derived_b.id].size).to eq(derived_b.srg_rules.count)

      # Numbering is one sequence across parents, primary's rules first.
      numbers = rules.map { |rule| rule.rule_id.to_i }
      expect(numbers.sort).to eq((1..rules.size).to_a)
      expect(by_parent[derived_a.id].map { |rule| rule.rule_id.to_i }.max)
        .to be < by_parent[derived_b.id].map { |rule| rule.rule_id.to_i }.min
    end

    it 'imports only the selected requirements per parent in selective mode' do
      selected_a = derived_a.srg_rules.order(:version).limit(2).pluck(:version)
      selected_b = derived_b.srg_rules.order(:version).limit(1).pluck(:version)

      described_class.new(stig_component)
                     .import_all!(selections: { derived_a.id => selected_a, derived_b.id => selected_b })

      rules = stig_component.rules.reload
      expect(rules.map(&:version)).to match_array(selected_a + selected_b)
      expect(rules.map { |rule| rule.rule_id.to_i }.sort).to eq([1, 2, 3])
    end
  end

  describe '#import_parent! (unknown kind)' do
    it 'raises rather than silently importing nothing' do
      component = build(:component, :skip_rules, document_type: 'unmapped')

      expect { described_class.new(component).import_parent!(core_a) }
        .to raise_error(ArgumentError, /unmapped/)
    end
  end
end
