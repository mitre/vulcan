# frozen_string_literal: true

module Export
  module Formatters
    # Generates XCCDF 1.1 XML from a component and its rules.
    # Component-based formatter — receives rich objects, not flat rows.
    #
    # Moved from ExportHelper#xccdf_helper, groups_helper, descriptions_helper,
    # checks_helper, ox_el_helper, ox_el_helper_ascii_str.
    class XccdfFormatter < BaseFormatter
      # Published SRGs carry nine MAC profiles — three mission assurance
      # categories crossed with three confidentiality levels. Every
      # published DISA SRG (and the core documents) selects every Group
      # in every profile; there is no differential selection to encode.
      MAC_CATEGORIES = {
        'MAC-1' => 'I - Mission Critical',
        'MAC-2' => 'II - Mission Support',
        'MAC-3' => 'III - Administrative'
      }.freeze
      CONFIDENTIALITY_LEVELS = %w[Classified Public Sensitive].freeze

      attr_reader :version_profile

      # Version variance (namespace, schemaLocation, id encoding) lives in
      # the profile — the content model below is version-agnostic.
      def initialize(version: Xccdf::VersionProfile::V1_1_4)
        super()
        @version_profile = version
      end

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

        # Benchmark root — XCCDF content-model order: version, then
        # Profiles, then Groups. Profiles are published-SRG shape only;
        # the STIG readiness emission is byte-locked by the corpus.
        benchmark = build_benchmark(component)
        build_profiles(benchmark, component, rules) if srg_component?(component)
        build_groups(benchmark, component, rules)
        doc << benchmark
      end

      # Published SRG documents use underscored benchmark ids
      # (General_Purpose_Operating_System); the STIG readiness emission
      # keeps the raw name — byte-locked by the corpus.
      def benchmark_id(component)
        return component[:name] unless srg_component?(component)

        SecurityRequirementsGuide.srg_id_from_name(component[:name])
      end

      def srg_component?(component)
        component.respond_to?(:document_type) && component.document_type == 'srg'
      end

      # Authored SRG requirement rows publish with the published-SRG shape;
      # Rule rows keep the STIG readiness shape byte-for-byte.
      def authored_srg?(rule)
        rule.is_a?(SrgRule)
      end

      def build_benchmark(component)
        benchmark = Ox::Element.new('Benchmark')
        benchmark['xmlns:dc'] = 'http://purl.org/dc/elements/1.1/'
        benchmark['xmlns:xsi'] = 'http://www.w3.org/2001/XMLSchema-instance'
        benchmark['xmlns:cpe'] = 'http://cpe.mitre.org/language/2.0'
        benchmark['xmlns:xhtml'] = 'http://www.w3.org/1999/xhtml'
        benchmark['xmlns:dsig'] = 'http://www.w3.org/2000/09/xmldsig#'
        benchmark['xsi:schemaLocation'] = version_profile.schema_location
        benchmark['id'] = version_profile.format_id(:benchmark, benchmark_id(component))
        benchmark['xml:lang'] = 'en'
        benchmark['xmlns'] = version_profile.namespace

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

        plain_text_tag = 'plain-text'
        release_info = "Release: #{component[:release]} Benchmark Date: #{Time.zone.today.strftime('%-d %b %Y')}"
        add_element(benchmark, plain_text_tag, release_info, { id: 'release-info' })
        add_element(benchmark, plain_text_tag, '3.2.2.36079', { id: 'generator' })
        add_element(benchmark, plain_text_tag, '1.10.0', { id: 'conventionsVersion' })
        add_element(benchmark, 'version', component[:version].to_s)

        benchmark
      end

      # Each MAC profile selects every emitted Group, in Group order —
      # the select list and the Group list are built from the same
      # sorted rows and the same id helper so they cannot drift.
      def build_profiles(benchmark, component, rules)
        rows = sorted_rules(rules)
        MAC_CATEGORIES.each do |category, category_title|
          CONFIDENTIALITY_LEVELS.each do |level|
            profile = Ox::Element.new('Profile')
            profile['id'] = version_profile.format_id(:profile, "#{category}_#{level}")
            add_element(profile, 'title', "#{category_title} #{level}")
            add_element(profile, 'description', '<ProfileDescription></ProfileDescription>')
            rows.each do |rule|
              add_element(profile, 'select', nil, { idref: group_id(component, rule), selected: 'true' })
            end
            benchmark << profile
          end
        end
      end

      # Sorted for deterministic output — Groups and profile selects
      # share this order.
      def sorted_rules(rules)
        rules.sort_by { |rule| rule[:id] }
      end

      def group_id(component, rule)
        version_profile.format_id(:group, "V-#{component[:prefix]}-#{rule[:rule_id]}")
      end

      def build_groups(benchmark, component, rules)
        sorted_rules(rules).each do |rule|
          srg_shape = authored_srg?(rule)
          group = Ox::Element.new('Group')
          group['id'] = group_id(component, rule)

          # Published SRG shape: the Group title is the core-half from the
          # row's own lineage; a net-new row carries its minted identifier,
          # or its working display name before release mints one — never an
          # empty title. STIG rows keep their SRG-ID version.
          working_name = "#{component[:prefix]}-#{rule[:rule_id]}"
          group_title = if srg_shape
                          rule.derived_from&.version || rule[:version].presence || working_name
                        else
                          rule[:version]
                        end
          add_element(group, 'title', group_title)
          add_element(group, 'description', '<GroupDescription></GroupDescription>') if srg_shape
          group_rule = Ox::Element.new('Rule')
          group_rule['id'] = version_profile.format_id(:rule, "SV-#{component[:prefix]}-#{rule[:rule_id]}")
          group_rule['severity'] = rule[:rule_severity] if rule[:rule_severity].present?
          group_rule['weight'] = rule[:rule_weight] if rule[:rule_weight].present?

          # SRG rows publish their minted identifier (working display name
          # before release mints one); STIG rows keep the working STIG-ID
          # convention.
          rule_version = srg_shape ? (rule[:version].presence || working_name) : working_name
          add_element(group_rule, 'version', rule_version)
          add_element(group_rule, 'title', rule[:title])
          build_descriptions(group_rule, rule)
          add_element(group_rule, 'ident', rule[:ident], { system: rule[:ident_system] })
          fixref = version_profile.format_id(:fix, "F-#{component[:prefix]}-#{rule[:rule_id]}_fix")
          add_element(group_rule, 'fixtext', rule[:fixtext], { fixref: fixref })
          add_element(group_rule, 'fix', nil, { id: fixref }) if srg_shape
          build_checks(group_rule, rule, component)

          group << group_rule
          benchmark << group
        end
      end

      # Satisfies is structurally absent on authored SrgRules — same guard
      # idiom as the backup serializer's satisfaction pass. Empty string
      # when the rule carries no satisfaction relations.
      def satisfaction_note(rule)
        return '' unless rule.respond_to?(:satisfies) && rule.satisfies.present?

        "\n\n#{rule.satisfaction_text(format: :srg)}"
      end

      def build_descriptions(group_rule, rule)
        rule.disa_rule_descriptions.each do |drd|
          desc = Ox::Element.new('description')

          desc_str = []
          # (value || '').dup — dup AFTER the fallback: a nil discussion
          # must not yield the frozen '' literal, which crashes any append.
          vuln_discussion = (drd[:vuln_discussion] || '').dup
          vuln_discussion << satisfaction_note(rule)
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

      def build_checks(group_rule, rule, component)
        srg_shape = authored_srg?(rule)
        rule.checks.each do |check|
          ch = Ox::Element.new('check')
          if srg_shape
            # Published SRG shape: working-convention check id and a
            # content-ref to the document itself, before the content.
            ch['system'] = "C-#{component[:prefix]}-#{rule[:rule_id]}_chk"
            add_element(ch, 'check-content-ref', nil,
                        { href: "#{benchmark_id(component)}_SRG.xml", name: 'M' })
          else
            ch['system'] = 'N/A'
          end
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
