# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: XccdfFormatter generates XCCDF 1.1 XML from a component and
# its rules. Output must match the structure produced by ExportHelper#xccdf_helper:
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
    let(:component) { create(:component) }
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
  end

  describe 'parity with ExportHelper' do
    include ExportHelper

    let(:component) do
      create(:component).tap do |c|
        # Set first rule to AC for a meaningful comparison
        c.rules.first.update_columns(status: status_ac)
      end
    end

    let(:ac_rules) do
      component.rules
               .eager_load(
                 :disa_rule_descriptions, :checks, :satisfies, :satisfied_by,
                 srg_rule: %i[disa_rule_descriptions rule_descriptions checks]
               )
               .where(status: status_ac)
               .where.not(id: RuleSatisfaction.select(:rule_id))
    end

    it 'produces XML structurally equivalent to ExportHelper#export_xccdf_component' do
      old_xml = export_xccdf_component(component)
      new_xml = formatter.generate_from_component(component: component, rules: ac_rules)

      # Parse both and compare structure (not exact string — whitespace may differ)
      old_doc = Ox.parse(old_xml)
      new_doc = Ox.parse(new_xml)

      # Same root element name
      expect(new_doc.nodes.last.name).to eq(old_doc.nodes.last.name)

      # Same number of Group elements
      old_groups = old_doc.nodes.last.nodes.select { |n| n.is_a?(Ox::Element) && n.name == 'Group' }
      new_groups = new_doc.nodes.last.nodes.select { |n| n.is_a?(Ox::Element) && n.name == 'Group' }
      expect(new_groups.size).to eq(old_groups.size)
    end
  end
end
