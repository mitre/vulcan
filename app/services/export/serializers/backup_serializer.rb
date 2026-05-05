# frozen_string_literal: true

module Export
  module Serializers
    # Serializes a component and its full object graph into a hash structure
    # suitable for JSON archive export. Preserves 100% of Vulcan data.
    #
    # Usage:
    #   serializer = BackupSerializer.new(component)
    #   data = serializer.serialize
    #   # => { component: {}, rules: [], satisfactions: [], reviews: [] }
    class BackupSerializer
      BACKUP_FORMAT_VERSION = '1.0'

      # base_rules columns to EXCLUDE from export (internal/relational IDs)
      EXCLUDED_RULE_COLUMNS = %w[
        id type component_id srg_rule_id review_requestor_id
        security_requirements_guide_id stig_id stig_rule_id
      ].freeze

      # @param component [Component] the component to serialize
      # @param preloaded_rules [Array<Rule>, nil] optional pre-eager-loaded rules
      #   When provided, uses these instead of re-querying (avoids N+1).
      def initialize(component, preloaded_rules: nil)
        @component = component
        @preloaded_rules = preloaded_rules
      end

      # Serialize the entire component object graph.
      def serialize
        {
          component: serialize_component,
          rules: serialize_rules,
          satisfactions: serialize_satisfactions,
          reviews: serialize_reviews
        }
      end

      # Build the manifest entry for this component (used by the archive).
      def manifest_entry
        {
          name: @component.name,
          prefix: @component.prefix,
          version: @component.version,
          release: @component.release,
          srg_id: @component.based_on&.srg_id,
          srg_title: @component.based_on&.title,
          srg_version: @component.based_on&.version,
          rule_count: rules_collection.size
        }
      end

      private

      def serialize_component
        {
          name: @component.name,
          prefix: @component.prefix,
          version: @component.version,
          release: @component.release,
          title: @component.title,
          description: @component.description,
          released: @component.released,
          admin_name: @component.admin_name,
          admin_email: @component.admin_email,
          advanced_fields: @component.advanced_fields,
          # closed_reason is 'adjudicating' / 'finalized' when closed,
          # null when open.
          comment_phase: @component.comment_phase,
          closed_reason: @component.closed_reason,
          comment_period_starts_at: @component.comment_period_starts_at&.iso8601,
          comment_period_ends_at: @component.comment_period_ends_at&.iso8601,
          created_at: @component.created_at&.iso8601,
          updated_at: @component.updated_at&.iso8601,
          based_on: {
            srg_id: @component.based_on&.srg_id,
            title: @component.based_on&.title,
            version: @component.based_on&.version
          },
          overlay_parent: serialize_overlay_parent,
          metadata: @component.component_metadata&.data,
          additional_questions: serialize_additional_questions
        }
      end

      def serialize_overlay_parent
        parent = @component.component
        return nil unless parent

        {
          name: parent.name,
          prefix: parent.prefix,
          project_name: parent.project&.name
        }
      end

      def serialize_additional_questions
        @component.additional_questions.order(:id).map do |q|
          {
            name: q.name,
            question_type: q.question_type,
            options: q.options
          }
        end
      end

      def rules_collection
        @preloaded_rules || @component.rules
      end

      def serialize_rules
        rules_collection.sort_by(&:rule_id).map { |rule| serialize_rule(rule) }
      end

      def serialize_rule(rule)
        attrs = rule_base_attributes(rule)
        attrs[:srg_rule_version] = rule.srg_rule&.version
        attrs[:disa_rule_descriptions] = serialize_disa_rule_descriptions(rule)
        attrs[:checks] = serialize_checks(rule)
        attrs[:rule_descriptions] = serialize_rule_descriptions(rule)
        attrs[:references] = serialize_references(rule)
        attrs[:additional_answers] = serialize_additional_answers(rule)
        attrs
      end

      def rule_base_attributes(rule)
        attrs = rule.attributes.except(*EXCLUDED_RULE_COLUMNS)
        # Ensure timestamps are ISO8601 strings
        attrs['created_at'] = rule.created_at&.iso8601
        attrs['updated_at'] = rule.updated_at&.iso8601
        attrs['deleted_at'] = rule.deleted_at&.iso8601
        attrs.symbolize_keys
      end

      def serialize_disa_rule_descriptions(rule)
        rule.disa_rule_descriptions.map do |drd|
          drd.attributes.except('id', 'base_rule_id', 'created_at', 'updated_at')
        end
      end

      def serialize_checks(rule)
        rule.checks.map do |check|
          check.attributes.except('id', 'base_rule_id', 'created_at', 'updated_at')
        end
      end

      def serialize_rule_descriptions(rule)
        rule.rule_descriptions.map do |rd|
          rd.attributes.except('id', 'base_rule_id', 'created_at', 'updated_at')
        end
      end

      def serialize_references(rule)
        rule.references.map do |ref|
          ref.attributes.except('id', 'base_rule_id', 'created_at', 'updated_at')
        end
      end

      def serialize_additional_answers(rule)
        rule.additional_answers.map do |aa|
          {
            question_name: aa.additional_question&.name,
            answer: aa.answer
          }
        end
      end

      def serialize_satisfactions
        satisfactions = []
        rules_collection.each do |rule|
          rule.satisfies.each do |satisfied_rule|
            # rule is the satisfier (satisfied_by_rule_id in DB)
            # satisfied_rule is the one being satisfied (rule_id in DB)
            satisfactions << {
              rule_id: satisfied_rule.rule_id,
              satisfied_by_rule_id: rule.rule_id
            }
          end
        end
        satisfactions
      end

      def serialize_reviews
        rules_collection.flat_map do |rule|
          rule.reviews.order(:created_at).map { |review| serialize_review(review, rule) }
        end
      end

      # external_id is the original DB id used as a stable in-archive key so
      # parent / duplicate cross-references can be re-linked on import without
      # the original DB ids surviving (re-import generates fresh ids).
      def serialize_review(review, rule)
        {
          external_id: review.id,
          rule_id: rule.rule_id,
          action: review.action,
          comment: review.comment,
          user_email: review.user&.email,
          user_name: review.user&.name,
          # public-comment-review lifecycle
          section: review.section,
          triage_status: review.triage_status,
          triage_set_by_email: review.triage_set_by&.email,
          triage_set_by_name: review.triage_set_by&.name,
          triage_set_at: review.triage_set_at&.iso8601,
          adjudicated_by_email: review.adjudicated_by&.email,
          adjudicated_by_name: review.adjudicated_by&.name,
          adjudicated_at: review.adjudicated_at&.iso8601,
          responding_to_external_id: review.responding_to_review_id,
          duplicate_of_external_id: review.duplicate_of_review_id,
          created_at: review.created_at&.iso8601
        }
      end
    end
  end
end
