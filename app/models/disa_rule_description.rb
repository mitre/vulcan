# frozen_string_literal: true

# Rule DisaRuleDescription class
class DisaRuleDescription < ApplicationRecord
  audited associated_with: :rule, except: %i[rule_id], max_audits: 1000
  belongs_to :rule

  # Because from_mappings take advantage of accepts_nested_attributes, these methods
  # must return Hashes instead of an actual object to be properly created and associated
  # with the rule.
  def self.from_mapping(disa_rule_description_mapping)
    include REXML
    # Because description is a freetext XHTML field, everything is parsed from text
    # with REXML to a hash

    # For REXML to parse multiple elements, a single root element must be provided
    # insert is a 'destructive' operation that needs to take place outside the begin/rescue
    # in case there is a retry
    disa_rule_description_mapping.insert(0, '<root>').insert(-1, '</root>')
    # retry once
    retried = false
    begin
      parsed_mapping = Hash.from_xml(disa_rule_description_mapping)
    rescue ::REXML::ParseException => e
      raise if e.continued_exception.is_a?(RuntimeError) && !retried && e.continued_exception.message.include?('"&"')

      disa_rule_description_mapping = disa_rule_description_mapping.gsub('&', '(literal ampersand)')
      retried = true
      retry
    end
    parsed_mapping = parsed_mapping['root']

    return unless parsed_mapping

    {
      vuln_discussion: parsed_mapping['VulnDiscussion'],
      false_positives: parsed_mapping['FalsePositives'],
      false_negatives: parsed_mapping['FalseNegatives'],
      documentable: parsed_mapping['Documentable'],
      mitigations: parsed_mapping['Mitigations'],
      severity_override_guidance: parsed_mapping['SeverityOverrideGuidance'],
      potential_impacts: parsed_mapping['PotentialImpact'],
      third_party_tools: parsed_mapping['ThirdPartyTools'],
      mitigation_control: parsed_mapping['MitigationControl'],
      responsibility: parsed_mapping['Responsibility'],
      ia_controls: parsed_mapping['IAControls']
    }
  end
end
