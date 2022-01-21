# frozen_string_literal: true

require 'zip'

# Helper methods for exports
module ExportHelper # rubocop:todo Metrics/ModuleLength
  include ExportConstants

  def export_excel(project)
    # One file for all data types, each data type in a different tab
    workbook = FastExcel.open(constant_memory: true)
    project.components.where(released: true).eager_load(
      rules: [:reviews, :disa_rule_descriptions, :rule_descriptions, :checks,
              :additional_answers, :satisfies, :satisfied_by, {
                srg_rule: %i[disa_rule_descriptions rule_descriptions checks]
              }]
    ).each do |component|
      worksheet = workbook.add_worksheet(component[:version])
      worksheet.auto_width = true
      worksheet.append_row(ExportConstants::DISA_EXPORT_HEADERS)
      last_row_num = 0
      component.rules.each do |rule|
        # fast_excel unfortunately does not provide a method to modify the @last_row_number class variable
        # so it needs to be manually kept track of
        last_row_num += 1
        rule.csv_attributes.each_with_index do |value, col_index|
          worksheet.write_string(last_row_num, col_index, value.to_s, nil)
        end
      end
    end

    workbook.close if workbook.is_open

    workbook
  end

  def export_xccdf(project)
    Zip::OutputStream.write_buffer do |zio|
      cls = 'U'
      prefix = project.components.first.prefix
      file_name = "#{cls}_#{project.name}_#{prefix}_Manual_STIG/#{cls}_#{project.name}_STIG_#{prefix}_Manual-xccdf.xml"
      zio.put_next_entry(file_name)

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
                                        'http://cpe.mitre.org/dictionary/2.0 '\
                                        'http://cpe.mitre.org/files/cpe-dictionary_2.1.xsd'
      benchmark['id'] = 'Active_Directory_Domain'
      benchmark['xml:lang'] = 'en'
      benchmark['xmlns'] = 'http://checklists.nist.gov/xccdf/1.1'

      ox_el_helper(benchmark, 'status', 'draft', { date: Time.zone.today.strftime('%Y-%m-%d') })
      ox_el_helper(benchmark, 'title', project[:name])
      ox_el_helper(benchmark, 'description', nil)
      ox_el_helper(benchmark, 'notice', nil, { id: 'terms-of-use', 'xml:lang': 'en' })
      ox_el_helper(benchmark, 'front-matter', nil, { 'xml:lang': 'en' })
      ox_el_helper(benchmark, 'rear-matter', nil, { 'xml:lang': 'en' })

      reference = Ox::Element.new('reference')
      reference['href'] = nil
      ox_el_helper(reference, 'dc:publisher', nil)
      ox_el_helper(reference, 'dc:source', nil)
      benchmark << reference

      ox_el_helper(benchmark, 'plain-text', nil, { id: 'release-info' })
      ox_el_helper(benchmark, 'plain-text', nil, { id: 'generator' })
      ox_el_helper(benchmark, 'plain-text', nil, { id: 'conventionsVersion' })
      ox_el_helper(benchmark, 'version', nil)

      components = project.components.eager_load(rules: %i[disa_rule_descriptions references checks])
      groups_helper(components, benchmark)

      doc << benchmark

      # Write xml to file
      zio.write Ox.dump(doc)
    end
  end

  private

  def groups_helper(components, benchmark)
    components.each do |component|
      component.rules.each do |rule|
        group = Ox::Element.new('Group')
        group['id'] = "V-#{rule[:rule_id]}"

        ox_el_helper(group, 'title', rule[:version].split('-')[0..-3].join('-'))
        group_rule = Ox::Element.new('Rule')
        group_rule['id'] = "SV-#{rule[:rule_id]}r#{rule[:rule_id]}rule"
        group_rule['severity'] = rule[:severity] if rule[:severity].present?
        group_rule['weight'] = rule[:weight] if rule[:weight].present?

        ox_el_helper(group_rule, 'version', rule[:version])
        ox_el_helper(group_rule, 'title', rule[:title])
        descriptions_helper(group_rule, rule)
        references_helper(group_rule, rule)
        ox_el_helper(group_rule, 'ident', rule[:ident], { system: rule[:ident_system] })
        ox_el_helper(group_rule, 'fixtext', rule[:fixtext], { fixref: rule[:fixtext_fixref] })
        ox_el_helper(group_rule, 'fix', nil, { id: rule[:fix_id] })
        checks_helper(group_rule, rule)

        group << group_rule

        benchmark << group
      end
    end
  end

  def descriptions_helper(group_rule, rule)
    rule.disa_rule_descriptions.each do |drd|
      desc = Ox::Element.new('description')

      desc_str = []
      desc_str << ox_el_helper_ascii_str('VulnDiscussion', drd[:vuln_discussion])
      desc_str << ox_el_helper_ascii_str('FalsePositives', drd[:false_positives])
      desc_str << ox_el_helper_ascii_str('FalseNegatives', drd[:false_negatives])
      desc_str << ox_el_helper_ascii_str('Documentable', drd[:documentable])
      desc_str << ox_el_helper_ascii_str('Mitigations', drd[:mitigations])
      desc_str << ox_el_helper_ascii_str('SecurityOverrideGuidance', drd[:severity_override_guidance])
      desc_str << ox_el_helper_ascii_str('PotentialImpacts', drd[:potential_impacts])
      desc_str << ox_el_helper_ascii_str('ThirdPartyTools', drd[:third_party_tools])
      desc_str << ox_el_helper_ascii_str('MitigationControl', drd[:mitigation_control])
      desc_str << ox_el_helper_ascii_str('Responsibility', drd[:responsibility])
      desc_str << ox_el_helper_ascii_str('IAControls', drd[:ia_controls])

      desc << desc_str.join

      group_rule << desc
    end
  end

  def references_helper(group_rule, rule)
    rule.references.each do |reference|
      ref = Ox::Element.new('reference')

      ox_el_helper(ref, 'dc:title', reference[:title])
      ox_el_helper(ref, 'dc:publisher', reference[:publisher])
      ox_el_helper(ref, 'dc:type', reference[:reference_type])
      ox_el_helper(ref, 'dc:subject', reference[:subject])
      ox_el_helper(ref, 'dc:identifier', reference[:identifier])

      group_rule << ref
    end
  end

  def checks_helper(group_rule, rule)
    rule.checks.each do |check|
      ch = Ox::Element.new('check')
      ch['system'] = check[:system]

      ox_el_helper(ch, 'check-content-ref', nil, { name: check[:content_ref_name], href: check[:content_ref_href] })
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
