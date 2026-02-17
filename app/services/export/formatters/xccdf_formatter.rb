# frozen_string_literal: true

module Export
  module Formatters
    # Generates XCCDF 1.1 XML from a component and its rules.
    # Component-based formatter — receives rich objects, not flat rows.
    #
    # Moved from ExportHelper#xccdf_helper, groups_helper, descriptions_helper,
    # checks_helper, ox_el_helper, ox_el_helper_ascii_str.
    class XccdfFormatter < BaseFormatter
      def component_based?
        true
      end

      def generate_from_component(component:, rules:)
        doc = build_document(component, rules)
        Ox.dump(doc)
      end

      def content_type
        'application/xml'
      end

      def file_extension
        '-xccdf.xml'
      end

      private

      def build_document(component, rules)
        doc = Ox::Document.new

        # XML declaration
        instruct_xml = Ox::Instruct.new(:xml)
        instruct_xml['version'] = '1.0'
        instruct_xml['encoding'] = 'UTF-8'
        doc << instruct_xml

        # Stylesheet processing instruction
        instruct_xsl = Ox::Instruct.new(:'xml-stylesheet')
        instruct_xsl['type'] = 'text/xsl'
        instruct_xsl['href'] = 'STIG_unclass.xsl'
        doc << instruct_xsl

        # Benchmark root
        benchmark = build_benchmark(component)
        build_groups(benchmark, component, rules)
        doc << benchmark
      end

      def build_benchmark(component)
        benchmark = Ox::Element.new('Benchmark')
        benchmark['xmlns:dc'] = 'http://purl.org/dc/elements/1.1/'
        benchmark['xmlns:xsi'] = 'http://www.w3.org/2001/XMLSchema-instance'
        benchmark['xmlns:cpe'] = 'http://cpe.mitre.org/language/2.0'
        benchmark['xmlns:xhtml'] = 'http://www.w3.org/1999/xhtml'
        benchmark['xmlns:dsig'] = 'http://www.w3.org/2000/09/xmldsig#'
        benchmark['xsi:schemaLocation'] = 'http://checklists.nist.gov/xccdf/1.1 ' \
                                          'http://nvd.nist.gov/schema/xccdf-1.1.4.xsd' \
                                          'http://cpe.mitre.org/dictionary/2.0 ' \
                                          'http://cpe.mitre.org/files/cpe-dictionary_2.1.xsd'
        benchmark['id'] = component[:name]
        benchmark['xml:lang'] = 'en'
        benchmark['xmlns'] = 'http://checklists.nist.gov/xccdf/1.1'

        add_element(benchmark, 'status', 'draft', { date: Time.zone.today.strftime('%Y-%m-%d') })
        title = component[:title] || "#{component[:name]} STIG Readiness Guide"
        add_element(benchmark, 'title', title)
        add_element(benchmark, 'description', component[:description] || title)
        add_element(benchmark, 'notice', nil, { id: 'terms-of-use', 'xml:lang': 'en' })
        add_element(benchmark, 'front-matter', nil, { 'xml:lang': 'en' })
        add_element(benchmark, 'rear-matter', nil, { 'xml:lang': 'en' })

        reference = Ox::Element.new('reference')
        reference['href'] = nil
        add_element(reference, 'dc:publisher', nil)
        add_element(reference, 'dc:source', nil)
        benchmark << reference

        release_info = "Release: #{component[:release]} Benchmark Date: #{Time.zone.today.strftime('%-d %b %Y')}"
        add_element(benchmark, 'plain-text', release_info, { id: 'release-info' })
        add_element(benchmark, 'plain-text', '3.2.2.36079', { id: 'generator' })
        add_element(benchmark, 'plain-text', '1.10.0', { id: 'conventionsVersion' })
        add_element(benchmark, 'version', component[:version].to_s)

        benchmark
      end

      def build_groups(benchmark, component, rules)
        groups = {}
        rules.each do |rule|
          group = Ox::Element.new('Group')
          group['id'] = "V-#{component[:prefix]}-#{rule[:rule_id]}"

          add_element(group, 'title', rule[:version])
          group_rule = Ox::Element.new('Rule')
          group_rule['id'] = "SV-#{component[:prefix]}-#{rule[:rule_id]}"
          group_rule['severity'] = rule[:rule_severity] if rule[:rule_severity].present?
          group_rule['weight'] = rule[:rule_weight] if rule[:rule_weight].present?

          add_element(group_rule, 'version', "#{component[:prefix]}-#{rule[:rule_id]}")
          add_element(group_rule, 'title', rule[:title])
          build_descriptions(group_rule, rule)
          add_element(group_rule, 'ident', rule[:ident], { system: rule[:ident_system] })
          add_element(group_rule, 'fixtext', rule[:fixtext],
                      { fixref: "F-#{component[:prefix]}-#{rule[:rule_id]}_fix" })
          build_checks(group_rule, rule)

          group << group_rule
          groups[rule[:id]] = group
        end

        # Sort by rule ID for deterministic output
        groups.keys.sort.each { |rule_id| benchmark << groups[rule_id] }
      end

      def build_descriptions(group_rule, rule)
        rule.disa_rule_descriptions.each do |drd|
          desc = Ox::Element.new('description')

          desc_str = []
          vuln_discussion = drd[:vuln_discussion].dup || ''
          vuln_discussion << "\n\n#{rule.satisfaction_text(format: :srg)}" if rule.satisfies.present?
          desc_str << ascii_element('VulnDiscussion', vuln_discussion)
          desc_str << ascii_element('FalsePositives', drd[:false_positives])
          desc_str << ascii_element('FalseNegatives', drd[:false_negatives])
          desc_str << ascii_element('Documentable', drd[:documentable])
          desc_str << ascii_element('Mitigations', drd[:mitigations])
          desc_str << ascii_element('SeverityOverrideGuidance', drd[:severity_override_guidance])
          desc_str << ascii_element('PotentialImpacts', drd[:potential_impacts])
          desc_str << ascii_element('ThirdPartyTools', drd[:third_party_tools])
          desc_str << ascii_element('MitigationControl', drd[:mitigation_control])
          desc_str << ascii_element('Responsibility', drd[:responsibility])
          desc_str << ascii_element('IAControls', drd[:ia_controls])

          desc << desc_str.join

          group_rule << desc
        end
      end

      def build_checks(group_rule, rule)
        rule.checks.each do |check|
          ch = Ox::Element.new('check')
          ch['system'] = 'N/A'
          add_element(ch, 'check-content', check[:content])
          group_rule << ch
        end
      end

      # Add a child element to parent with optional text content and attributes.
      def add_element(parent, name, child, attributes = nil)
        el = Ox::Element.new(name)
        attributes&.each { |k, v| el[k] = v }
        el << child if child.present?
        parent << el
      end

      # Build an ASCII XML element string (not a real Ox element — embedded in description).
      def ascii_element(name, value)
        "<#{name}>#{value}</#{name}>"
      end
    end
  end
end
