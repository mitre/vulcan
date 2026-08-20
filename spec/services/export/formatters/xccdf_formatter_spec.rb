# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: XccdfFormatter generates XCCDF 1.1 XML from a component and
# its rules, byte-locked by the corpus fixtures. The required structure:
# - XML declaration + stylesheet processing instruction
# - Benchmark root with correct namespaces
# - Status, title, description, reference, version elements
# - One Group per rule with Rule child (severity, weight, version, title,
#   description with VulnDiscussion, ident, fixtext, check)
# - Satisfaction text embedded in VulnDiscussion
# ==========================================================================
RSpec.describe Export::Formatters::XccdfFormatter do
  subject(:formatter) { described_class.new }

  let(:status_ac) { 'Applicable - Configurable' }

  describe '#component_based?' do
    it 'returns true' do
      expect(formatter.component_based?).to be true
    end
  end

  describe '#content_type' do
    it 'returns application/xml' do
      expect(formatter.content_type).to eq('application/xml')
    end
  end

  describe '#file_extension' do
    it 'returns -xccdf.xml' do
      expect(formatter.file_extension).to eq('-xccdf.xml')
    end
  end

  describe '#generate_from_component' do
    let_it_be(:component) { create(:component) }
    let(:ac_rules) do
      rules = component.rules.eager_load(
        :disa_rule_descriptions, :checks, :satisfies, :satisfied_by,
        srg_rule: %i[disa_rule_descriptions rule_descriptions checks]
      ).order(:rule_id)

      # Set first rule to AC for testing
      rules.first.update_columns(status: status_ac)
      # Reload to get fresh status
      rules.where(status: status_ac)
    end

    let(:xml_string) { formatter.generate_from_component(component: component, rules: ac_rules) }

    it 'returns a string' do
      expect(xml_string).to be_a(String)
    end

    it 'starts with XML declaration' do
      expect(xml_string).to start_with('<?xml ')
    end

    it 'contains xml-stylesheet processing instruction' do
      expect(xml_string).to include('xml-stylesheet')
      expect(xml_string).to include('STIG_unclass.xsl')
    end

    it 'has Benchmark root element with correct namespace' do
      expect(xml_string).to include('<Benchmark')
      expect(xml_string).to include('xmlns="http://checklists.nist.gov/xccdf/1.1"')
    end

    it 'includes component name as Benchmark id' do
      expect(xml_string).to include("id=\"#{component.name}\"")
    end

    it 'includes component version' do
      expect(xml_string).to include("<version>#{component.version}</version>")
    end

    it 'includes component title' do
      expect(xml_string).to include("<title>#{component.title}</title>")
    end

    it 'includes release-info plain-text' do
      expect(xml_string).to include('id="release-info"')
      expect(xml_string).to include("Release: #{component.release}")
    end

    it 'creates a Group for each rule' do
      expect(xml_string).to include('<Group')
      expect(xml_string.scan('<Group').count).to eq(ac_rules.count)
    end

    it 'includes rule version in Group title' do
      rule = ac_rules.first
      expect(xml_string).to include("<title>#{rule.version}</title>")
    end

    it 'includes Rule element with severity' do
      rule = ac_rules.first
      expect(xml_string).to include('<Rule')
      expect(xml_string).to include("severity=\"#{rule.rule_severity}\"") if rule.rule_severity.present?
    end

    it 'includes VulnDiscussion in description' do
      # VulnDiscussion is embedded as ASCII string inside <description>,
      # so Ox escapes it as &lt;VulnDiscussion&gt;
      expect(xml_string).to include('&lt;VulnDiscussion&gt;')
    end

    it 'includes check-content' do
      expect(xml_string).to include('<check-content')
    end

    it 'includes fixtext' do
      expect(xml_string).to include('<fixtext')
    end

    it 'includes ident element' do
      expect(xml_string).to include('<ident')
    end

    it 'emits no Profile elements — the STIG readiness shape carries none (byte-locked by the corpus)' do
      expect(xml_string).not_to include('<Profile')
    end
  end

  describe '#generate_from_component with authored SRG requirements' do
    let_it_be(:core) do
      create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-XCCDF-GUARD', version: 'V1R1')
    end
    let_it_be(:core_row) do
      create(:srg_rule, security_requirements_guide: core, version: 'SRG-OS-000701')
    end
    let_it_be(:srg_component) do
      create(:component, :skip_rules, document_type: 'srg', based_on: core, prefix: 'XFMT-00')
    end

    it 'formats authored SrgRules without emitting satisfies structures — satisfies is structurally absent' do
      row = create(:srg_rule, :authored, component: srg_component, version: 'SRG-OS-000701',
                                         rule_id: '000801', status: 'Applicable',
                                         derived_from_srg_rule_id: core_row.id)
      row.checks.create!(system: 'C-xfmt', content: 'Authored check content')

      xml_string = formatter.generate_from_component(component: srg_component,
                                                     rules: srg_component.authored_srg_rules)

      expect(xml_string).to include('SRG-OS-000701')
      expect(xml_string).to include('Authored check content')
      expect(xml_string).not_to include('Satisfies')
    end

    # Published DISA SRGs carry nine MAC profiles — 3 mission assurance
    # categories x 3 confidentiality levels — each selecting every Group
    # (verified against every published SRG in db/seeds/srgs and the OS
    # Core document: no differential selection exists).
    it 'emits the nine MAC profiles between version and the Groups, each selecting every Group' do
      %w[000801 000802].each do |rule_id|
        create(:srg_rule, :authored, component: srg_component, version: nil,
                                     rule_id: rule_id, status: 'Applicable',
                                     derived_from_srg_rule_id: core_row.id)
      end

      xml_string = formatter.generate_from_component(component: srg_component,
                                                     rules: srg_component.authored_srg_rules)
      benchmark = Ox.parse(xml_string).nodes.last
      children = benchmark.nodes.grep(Ox::Element)
      names = children.map(&:name)
      profiles = children.select { |n| n.name == 'Profile' }
      group_ids = children.select { |n| n.name == 'Group' }.pluck('id')

      expect(profiles.pluck('id')).to eq(
        %w[MAC-1_Classified MAC-1_Public MAC-1_Sensitive
           MAC-2_Classified MAC-2_Public MAC-2_Sensitive
           MAC-3_Classified MAC-3_Public MAC-3_Sensitive]
      )
      titles = profiles.map { |p| p.nodes.find { |n| n.is_a?(Ox::Element) && n.name == 'title' }.text }
      expect(titles).to eq(
        ['I - Mission Critical Classified', 'I - Mission Critical Public',
         'I - Mission Critical Sensitive', 'II - Mission Support Classified',
         'II - Mission Support Public', 'II - Mission Support Sensitive',
         'III - Administrative Classified', 'III - Administrative Public',
         'III - Administrative Sensitive']
      )
      descriptions = profiles.map { |p| p.nodes.find { |n| n.is_a?(Ox::Element) && n.name == 'description' }.text }
      expect(descriptions.uniq).to eq(['<ProfileDescription></ProfileDescription>'])

      expect(group_ids).to eq(%w[V-XFMT-00-000801 V-XFMT-00-000802])
      profiles.each do |profile|
        selects = profile.nodes.select { |n| n.is_a?(Ox::Element) && n.name == 'select' }
        expect(selects.map { |s| s['idref'] }).to eq(group_ids)
        expect(selects.map { |s| s['selected'] }.uniq).to eq(['true'])
      end

      # XCCDF benchmark order: version, then Profiles, then Groups.
      expect(names.index('Profile')).to be > names.index('version')
      expect(names.rindex('Profile')).to be < names.index('Group')
    end
  end
end
