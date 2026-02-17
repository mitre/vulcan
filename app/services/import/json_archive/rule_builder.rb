# frozen_string_literal: true

module Import
  module JsonArchive
    # Creates Rules from backup JSON data within a component.
    # Links each rule to its SRG rule by version match.
    # Returns a mapping of { rule_id_string => new_db_id } for satisfaction rebuilding.
    class RuleBuilder
      # base_rules columns that map directly from the serialized data.
      # Excludes timestamps (restored separately) and nested records.
      DIRECT_COLUMNS = %w[
        locked status status_justification artifact_description vendor_comments
        rule_id rule_severity rule_weight version title ident ident_system
        fixtext fixtext_fixref fix_id changes_requested
        inspec_control_body inspec_control_file
        inspec_control_body_lang inspec_control_file_lang
        deleted_at srg_id vuln_id legacy_ids
      ].freeze

      def initialize(rules_data, component, result)
        @rules_data = rules_data
        @component = component
        @result = result
        @srg_rules = load_srg_rules
      end

      # Returns { rule_id_string => new_db_id }
      def build_all
        rule_id_map = {}

        @rules_data.each do |rule_data|
          rule = build_rule(rule_data)
          next unless rule

          rule_id_map[rule.rule_id] = rule.id
        end

        @component.update_columns(rules_count: @component.rules.where(deleted_at: nil).count) # rubocop:disable Rails/SkipsModelValidations -- reset counter cache after bulk import
        rule_id_map
      end

      private

      def load_srg_rules
        srg_id = @component.security_requirements_guide_id
        return {} unless srg_id

        SrgRule.where(security_requirements_guide_id: srg_id).index_by(&:version)
      end

      def build_rule(rule_data)
        srg_rule = resolve_srg_rule(rule_data)

        rule = @component.rules.new
        rule.skip_update_inspec_code = true

        assign_direct_columns(rule, rule_data)
        rule.srg_rule_id = srg_rule&.id
        rule.component_id = @component.id

        build_nested_records(rule, rule_data)

        unless rule.save
          @result.add_error("Rule #{rule_data['rule_id']}: #{rule.errors.full_messages.join(', ')}")
          return nil
        end

        restore_timestamps(rule, rule_data)
        build_additional_answers(rule, rule_data)

        rule
      end

      def resolve_srg_rule(rule_data)
        version = rule_data['srg_rule_version']
        return nil unless version

        srg_rule = @srg_rules[version]
        @result.add_warning("SRG rule '#{version}' not found for rule #{rule_data['rule_id']}") unless srg_rule
        srg_rule
      end

      def assign_direct_columns(rule, rule_data)
        DIRECT_COLUMNS.each do |col|
          next unless rule_data.key?(col)

          value = rule_data[col]
          # Handle deleted_at as a datetime
          value = Time.zone.parse(value) if col == 'deleted_at' && value.is_a?(String)
          rule.send(:"#{col}=", value)
        end
      end

      def build_nested_records(rule, rule_data)
        build_disa_rule_descriptions(rule, rule_data)
        build_checks(rule, rule_data)
        build_rule_descriptions(rule, rule_data)
        build_references(rule, rule_data)
      end

      def build_disa_rule_descriptions(rule, rule_data)
        descriptions = rule_data['disa_rule_descriptions']
        return unless descriptions.is_a?(Array) && descriptions.any?

        # Clear default disa_rule_description (created by before_create callback)
        rule.disa_rule_descriptions.clear

        descriptions.each do |drd_data|
          rule.disa_rule_descriptions.build(
            drd_data.slice(
              'vuln_discussion', 'false_positives', 'false_negatives', 'documentable',
              'mitigations', 'severity_override_guidance', 'potential_impacts',
              'third_party_tools', 'mitigation_control', 'responsibility', 'ia_controls',
              'mitigations_available', 'poam_available', 'poam'
            )
          )
        end
      end

      def build_checks(rule, rule_data)
        checks = rule_data['checks']
        return unless checks.is_a?(Array) && checks.any?

        rule.checks.clear

        checks.each do |check_data|
          rule.checks.build(
            check_data.slice('system', 'content_ref_name', 'content_ref_href', 'content')
          )
        end
      end

      def build_rule_descriptions(rule, rule_data)
        descriptions = rule_data['rule_descriptions']
        return unless descriptions.is_a?(Array) && descriptions.any?

        descriptions.each do |rd_data|
          rule.rule_descriptions.build(description: rd_data['description'])
        end
      end

      def build_references(rule, rule_data)
        references = rule_data['references']
        return unless references.is_a?(Array) && references.any?

        references.each do |ref_data|
          rule.references.build(
            ref_data.slice(
              'description', 'format', 'identifier', 'language',
              'publisher', 'relation', 'rights', 'source',
              'subject', 'title', 'reference_type'
            )
          )
        end
      end

      def build_additional_answers(rule, rule_data)
        answers = rule_data['additional_answers']
        return unless answers.is_a?(Array) && answers.any?

        answers.each do |aa_data|
          question = @component.additional_questions.find_by(name: aa_data['question_name'])
          unless question
            @result.add_warning(
              "Question '#{aa_data['question_name']}' not found for rule #{rule.rule_id}. Answer skipped."
            )
            next
          end

          AdditionalAnswer.create!(
            rule: rule,
            additional_question: question,
            answer: aa_data['answer']
          )
        end
      end

      def restore_timestamps(rule, rule_data)
        updates = {}
        updates[:created_at] = Time.zone.parse(rule_data['created_at']) if rule_data['created_at']
        updates[:updated_at] = Time.zone.parse(rule_data['updated_at']) if rule_data['updated_at']
        rule.update_columns(updates) if updates.any? # rubocop:disable Rails/SkipsModelValidations -- restoring original timestamps from backup
      end
    end
  end
end
