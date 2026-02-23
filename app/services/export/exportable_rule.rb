# frozen_string_literal: true

module Export
  # Decorator wrapping a Rule that provides named key-based access to export columns.
  # Replaces positional array indexing in csv_attributes with named keys,
  # making mode transforms and formatter access clear and maintainable.
  class ExportableRule
    # The 19 keys matching the positional order of Rule#csv_attributes (0-18).
    CSV_KEYS = %i[
      nist_control_family
      ident
      srg_id
      stig_id
      srg_title
      title
      srg_vuln_discussion
      vuln_discussion
      status
      srg_check
      check_content
      srg_fix
      fixtext
      severity
      mitigation
      artifact_description
      status_justification
      vendor_comments
      satisfies
    ].freeze

    # All 20 export column keys including the optional InSpec control body.
    ALL_KEYS = [*CSV_KEYS, :inspec_control_body].freeze

    # Full set of queryable keys (ALL_KEYS + metadata keys like :source).
    QUERYABLE_KEYS = [*ALL_KEYS, :source].freeze

    attr_reader :rule

    delegate :status, :rule_severity, :rule_id, :version, to: :rule

    def initialize(rule)
      @rule = rule
    end

    def value_for(key)
      raise ArgumentError, "Unknown export key: #{key}" unless QUERYABLE_KEYS.include?(key)

      send(:"fetch_#{key}")
    end

    def values_for(keys)
      keys.map { |key| value_for(key) }
    end

    private

    def fetch_nist_control_family
      rule.nist_control_family
    end

    def fetch_ident
      rule.ident
    end

    def fetch_srg_id
      rule.version
    end

    def fetch_stig_id
      "#{rule.component.prefix}-#{rule.rule_id}"
    end

    def fetch_srg_title
      rule.srg_rule.title
    end

    def fetch_title
      rule.title
    end

    def fetch_srg_vuln_discussion
      rule.srg_rule.disa_rule_descriptions.first&.vuln_discussion
    end

    def fetch_vuln_discussion
      rule.disa_rule_descriptions.first&.vuln_discussion
    end

    def fetch_status
      rule.status
    end

    def fetch_srg_check
      rule.srg_rule.checks.first&.content
    end

    def fetch_check_content
      # export_checktext is private on Rule but used by csv_attributes internally.
      # We replicate its logic here rather than breaking encapsulation.
      # Use .order(:id).first for deterministic results when multiple satisfied_by exist.
      if rule.satisfied_by.size.positive?
        rule.satisfied_by.order(:id).first.checks.first&.content
      else
        rule.checks.first&.content
      end
    end

    def fetch_srg_fix
      rule.srg_rule.fixtext
    end

    def fetch_fixtext
      # export_fixtext is private on Rule but used by csv_attributes internally.
      # We replicate its logic here rather than breaking encapsulation.
      # Use .order(:id).first for deterministic results when multiple satisfied_by exist.
      if rule.satisfied_by.size.positive?
        rule.satisfied_by.order(:id).first.fixtext
      else
        rule.fixtext
      end
    end

    def fetch_severity
      RuleConstants::SEVERITIES_MAP[rule.rule_severity] || rule.rule_severity
    end

    def fetch_mitigation
      rule.disa_rule_descriptions.first&.mitigations
    end

    def fetch_artifact_description
      rule.artifact_description
    end

    def fetch_status_justification
      rule.status_justification
    end

    def fetch_vendor_comments
      rule.vendor_comments
    end

    def fetch_satisfies
      rule.satisfaction_text(format: :stig, direction: :satisfies)
    end

    def fetch_inspec_control_body
      rule.inspec_control_body
    end

    def fetch_source
      rule.satisfied_by.any? ? 'Inherited' : 'Direct'
    end
  end
end
