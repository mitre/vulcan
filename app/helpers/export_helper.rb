# frozen_string_literal: true

require 'zip'

# Helper methods for exports
module ExportHelper # rubocop:todo Metrics/ModuleLength
  include ExportConstants

  DISA_STATUS_TEXTS = {
    'Not Applicable' => {
      'check_text' => 'This requirement is NA for this technology.',
      'fix_text' => 'The requirement is NA. No fix is required.'
    },
    'Applicable - Inherently Meets' => {
      'check_text' => 'The technology supports this requirement and cannot be configured to be out of compliance. ' \
                      'The technology inherently meets this requirement.',
      'fix_text' => 'This technology inherently meets this requirement. No fix is required.'
    },
    'Applicable - Does Not Meet' => {
      'check_text' => 'The technology does not support this requirement. This is an applicable-does not meet finding.',
      'fix_text' => 'This requirement is a permanent finding and cannot be fixed. ' \
                    'An appropriate mitigation for the system must be implemented, ' \
                    'but this finding cannot be considered fixed.'
    }
  }.freeze

  # Named field keys for DISA export content modification.
  # Used with csv_attributes_hash to avoid fragile positional indices.
  DISA_MODIFIABLE_FIELDS = ['Check', 'Fix', 'Status Justification', 'Mitigation', 'Artifact Description'].freeze

  def export_excel(project, component_ids, is_disa_export)
    components_to_export = project.components.where(id: component_ids.split(','))
    package = Axlsx::Package.new
    package.use_shared_strings = true

    wrap_style = package.workbook.styles.add_style(alignment: { wrap_text: true })

    components_to_export.eager_load(
      rules: [:reviews, :disa_rule_descriptions, :rule_descriptions, :checks,
              :additional_answers, :satisfies, :satisfied_by, {
                srg_rule: %i[disa_rule_descriptions rule_descriptions checks]
              }]
    ).sort.each do |component|
      name_ending = "-V#{component[:version]}R#{component[:release]}-#{component[:id]}"
      # excel worksheet name has a limit of 31 characters
      worksheet_name = component[:name].gsub(/\s+/, '').first(31 - name_ending.length) + name_ending
      headers = is_disa_export ? ExportConstants::DISA_EXPORT_HEADERS : ExportConstants::EXPORT_HEADERS

      package.workbook.add_worksheet(name: worksheet_name) do |ws|
        ws.add_row(headers, types: Array.new(headers.size, :string))

        component.rules.order(:version, :rule_id).each do |rule|
          attrs = rule.csv_attributes_hash

          if is_disa_export
            apply_disa_content_rules!(attrs, rule.status)
            row = attrs.values_at(*headers)
          else
            row = attrs.values_at(*ExportConstants::DISA_EXPORT_HEADERS)
            row << rule.inspec_control_body
          end

          ws.add_row(
            row.map(&:to_s),
            types: Array.new(row.size, :string),
            style: wrap_style
          )
        end
      end
    end

    package
  end

  def get_check_and_fix_text(status)
    # this following helps in modifying check_text and fix_text when the user has opted for DISA Excel Export
    DISA_STATUS_TEXTS[status]
  end

  # Apply DISA content rules to a csv_attributes_hash.
  # Replaces check/fix with boilerplate for non-AC statuses,
  # and blanks fields that should be empty per status.
  def apply_disa_content_rules!(attrs, status)
    # Replace check/fix with DISA boilerplate for non-AC/non-NYD statuses
    if status != 'Applicable - Configurable' && status != 'Not Yet Determined'
      texts = get_check_and_fix_text(status)
      if texts
        attrs['Check'] = texts['check_text']
        attrs['Fix'] = texts['fix_text']
      end
    end

    # Blank fields per DISA Process Guide field requirements
    case status
    when 'Applicable - Configurable'
      attrs['Status Justification'] = nil
      attrs['Mitigation'] = nil
      attrs['Artifact Description'] = nil
    when 'Applicable - Inherently Meets'
      attrs['Mitigation'] = nil
    when 'Not Applicable'
      attrs['Mitigation'] = nil
      attrs['Artifact Description'] = nil
    end
  end

  def export_xccdf_project(project, component_ids: nil)
    scope = component_ids ? project.components.where(id: component_ids) : project.components
    Zip::OutputStream.write_buffer do |zio|
      scope.eager_load(rules: %i[disa_rule_descriptions checks
                                 satisfies satisfied_by]).find_each do |component|
        version = component[:version] ? "V#{component[:version]}" : ''
        release = component[:release] ? "R#{component[:release]}" : ''
        title = component[:title] || "#{component[:name]} STIG Readiness Guide"
        file_name = "U_#{title.tr(' ', '_')}_#{version}#{release}-xccdf.xml"
        zio.put_next_entry(file_name)

        doc = xccdf_helper(component)

        # Write xml to file
        zio.write Ox.dump(doc)
      end
    end
  end

  def export_inspec_project(project, component_ids: nil)
    scope = component_ids ? project.components.where(id: component_ids) : project.components
    Zip::OutputStream.write_buffer do |zio|
      scope.eager_load(rules: %i[disa_rule_descriptions checks
                                 satisfies satisfied_by]).find_each do |component|
        version = component[:version] ? "V#{component[:version]}" : ''
        release = component[:release] ? "R#{component[:release]}" : ''
        dir = "#{component[:name].tr(' ', '-')}-#{version}#{release}-stig-baseline/"
        inspec_helper(zio, component, dir)
      end
    end
  end

  def export_xccdf_component(component)
    doc = xccdf_helper(component)
    Ox.dump(doc)
  end

  def export_inspec_component(component)
    Zip::OutputStream.write_buffer do |zio|
      inspec_helper(zio, component, '')
    end
  end

  private

  def inspec_helper(zio, component, dir)
    zio.put_next_entry("#{dir}inspec.yml")
    inspec_yml = {
      name: component[:name],
      title: component[:title],
      maintainer: component[:admin_name],
      summary: component[:description]
    }
    zio.write YAML.dump(inspec_yml)
    component.rules.each do |rule|
      next if rule.satisfied_by.present?

      control_path = "#{dir}controls/#{component[:prefix]}-#{rule[:rule_id]}.rb"

      if rule[:status] == 'Applicable - Configurable'
        zio.put_next_entry(control_path)
        zio.write rule.inspec_control_file
      elsif rule[:status] == 'Not Yet Determined'
        zio.put_next_entry(control_path)
        zio.write generate_nyd_stub_control(component, rule)
      end
      # Other statuses (NA, Satisfied By, Inherently Meets, Does Not Meet) excluded
    end
  end

  def generate_nyd_stub_control(component, rule)
    <<~RUBY
      # TODO: Status is 'Not Yet Determined' — this control requires review.
      control '#{component[:prefix]}-#{rule[:rule_id]}' do
        impact 0.0
        title '#{rule[:title].to_s.gsub("'", "\\\\'")}'
        desc 'Not Yet Determined — stub control generated by Vulcan.'
        tag status: 'Not Yet Determined'
      end
    RUBY
  end

  def xccdf_helper(component)
    doc = Ox::Document.new

    # Document Headers
    instruct_xml = Ox::Instruct.new(:xml)
    instruct_xml['version'] = '1.0'
    instruct_xml['encoding'] = 'UTF-8'
    doc << instruct_xml

    instruct_xml_s = Ox::Instruct.new(:'xml-stylesheet')
    instruct_xml_s['type'] = 'text/xsl'
    instruct_xml_s['href'] = 'STIG_unclass.xsl'
    doc << instruct_xml_s

    # Root Benchmark element
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

    ox_el_helper(benchmark, 'status', 'draft', { date: Time.zone.today.strftime('%Y-%m-%d') })
    title = component[:title] || "#{component[:name]} STIG Readiness Guide"
    ox_el_helper(benchmark, 'title', title)
    ox_el_helper(benchmark, 'description', component[:description] || title)
    ox_el_helper(benchmark, 'notice', nil, { id: 'terms-of-use', 'xml:lang': 'en' })
    ox_el_helper(benchmark, 'front-matter', nil, { 'xml:lang': 'en' })
    ox_el_helper(benchmark, 'rear-matter', nil, { 'xml:lang': 'en' })

    reference = Ox::Element.new('reference')
    reference['href'] = nil
    ox_el_helper(reference, 'dc:publisher', nil)
    ox_el_helper(reference, 'dc:source', nil)
    benchmark << reference

    release_info = "Release: #{component[:release]} Benchmark Date: #{Time.zone.today.strftime('%-d %b %Y')}"
    ox_el_helper(benchmark, 'plain-text', release_info, { id: 'release-info' })
    ox_el_helper(benchmark, 'plain-text', '3.2.2.36079', { id: 'generator' })
    ox_el_helper(benchmark, 'plain-text', '1.10.0', { id: 'conventionsVersion' })
    ox_el_helper(benchmark, 'version', component[:version].to_s)

    groups_helper(component, benchmark)

    doc << benchmark
  end

  def groups_helper(component, benchmark)
    groups = {}
    component.rules.each do |rule|
      # Rules are filtered here to prevent n + 1 query
      next unless rule[:status] == 'Applicable - Configurable'
      next if rule.satisfied_by.present?

      group = Ox::Element.new('Group')
      group['id'] = "V-#{component[:prefix]}-#{rule[:rule_id]}"

      ox_el_helper(group, 'title', rule[:version])
      group_rule = Ox::Element.new('Rule')
      group_rule['id'] = "SV-#{component[:prefix]}-#{rule[:rule_id]}"
      group_rule['severity'] = rule[:rule_severity] if rule[:rule_severity].present?
      group_rule['weight'] = rule[:rule_weight] if rule[:rule_weight].present?

      ox_el_helper(group_rule, 'version', "#{component[:prefix]}-#{rule[:rule_id]}")
      ox_el_helper(group_rule, 'title', rule[:title])
      descriptions_helper(group_rule, rule)
      ox_el_helper(group_rule, 'ident', rule[:ident], { system: rule[:ident_system] })
      ox_el_helper(group_rule, 'fixtext', rule[:fixtext], { fixref: "F-#{component[:prefix]}-#{rule[:rule_id]}_fix" })
      checks_helper(group_rule, rule)

      group << group_rule
      groups[rule[:id]] = group
    end

    # Groups are sorted here to prevent n + 1 query
    groups.keys.sort.each { |rule_id| benchmark << groups[rule_id] }
  end

  def descriptions_helper(group_rule, rule)
    rule.disa_rule_descriptions.each do |drd|
      desc = Ox::Element.new('description')

      desc_str = []
      vuln_discussion = drd[:vuln_discussion]
      vuln_discussion << "\n\n#{rule.satisfaction_text(format: :srg)}" if rule.satisfies.present?
      desc_str << ox_el_helper_ascii_str('VulnDiscussion', vuln_discussion)
      desc_str << ox_el_helper_ascii_str('FalsePositives', drd[:false_positives])
      desc_str << ox_el_helper_ascii_str('FalseNegatives', drd[:false_negatives])
      desc_str << ox_el_helper_ascii_str('Documentable', drd[:documentable])
      desc_str << ox_el_helper_ascii_str('Mitigations', drd[:mitigations])
      desc_str << ox_el_helper_ascii_str('SeverityOverrideGuidance', drd[:severity_override_guidance])
      desc_str << ox_el_helper_ascii_str('PotentialImpacts', drd[:potential_impacts])
      desc_str << ox_el_helper_ascii_str('ThirdPartyTools', drd[:third_party_tools])
      desc_str << ox_el_helper_ascii_str('MitigationControl', drd[:mitigation_control])
      desc_str << ox_el_helper_ascii_str('Responsibility', drd[:responsibility])
      desc_str << ox_el_helper_ascii_str('IAControls', drd[:ia_controls])

      desc << desc_str.join

      group_rule << desc
    end
  end

  def checks_helper(group_rule, rule)
    rule.checks.each do |check|
      ch = Ox::Element.new('check')
      ch['system'] = 'N/A'

      ox_el_helper(ch, 'check-content', check[:content])

      group_rule << ch
    end
  end

  def ox_el_helper(parent, name, child, attributes = nil)
    el = Ox::Element.new(name)
    attributes&.each { |k, v| el[k] = v }
    el << child if child.present?
    parent << el
  end

  def ox_el_helper_ascii_str(name, value)
    "<#{name}>#{value}</#{name}>"
  end
end
