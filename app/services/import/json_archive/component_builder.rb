# frozen_string_literal: true

module Import
  module JsonArchive
    # Creates a Component from backup JSON data.
    # Looks up SRG by srg_id + version, creates metadata and additional questions.
    class ComponentBuilder
      def initialize(component_data, project, result)
        @data = component_data
        @project = project
        @result = result
      end

      def build
        srg = resolve_srg
        return nil unless srg

        component = @project.components.new(
          name: @data['name'],
          prefix: @data['prefix'],
          version: @data['version'],
          release: @data['release'],
          title: @data['title'].presence || @data['name'],
          description: @data['description'],
          released: @data['released'] || false,
          admin_name: @data['admin_name'],
          admin_email: @data['admin_email'],
          advanced_fields: @data['advanced_fields'] || false,
          security_requirements_guide_id: srg.id,
          # PR #717 — public-comment-review lifecycle. Skip when the field is
          # absent so older backup archives without these fields still import.
          comment_phase: @data['comment_phase'].presence || 'draft',
          comment_period_starts_at: @data['comment_period_starts_at'],
          comment_period_ends_at: @data['comment_period_ends_at']
        )
        component.skip_import_srg_rules = true

        resolve_overlay_parent(component)
        build_additional_questions(component)

        unless component.save
          component.errors.full_messages.each { |msg| @result.add_error("Component: #{msg}") }
          return nil
        end

        build_metadata(component)
        restore_timestamps(component)

        component
      end

      private

      def resolve_srg
        based_on = @data['based_on']
        return nil unless based_on

        srg = SecurityRequirementsGuide.find_by(srg_id: based_on['srg_id'], version: based_on['version'])
        srg ||= SecurityRequirementsGuide.find_by(srg_id: based_on['srg_id'])

        @result.add_error("Cannot find SRG: #{based_on['title']} (#{based_on['srg_id']})") unless srg

        srg
      end

      def resolve_overlay_parent(component)
        parent_data = @data['overlay_parent']
        return unless parent_data

        parent = Component.find_by(name: parent_data['name'], prefix: parent_data['prefix'])
        if parent
          component.component_id = parent.id
        else
          @result.add_warning(
            "Overlay parent '#{parent_data['name']}' not found. Imported without overlay link."
          )
        end
      end

      def build_additional_questions(component)
        questions = @data['additional_questions']
        return unless questions.is_a?(Array)

        questions.each do |q_data|
          component.additional_questions.build(
            name: q_data['name'],
            question_type: q_data['question_type'],
            options: q_data['options'] || []
          )
        end
      end

      def build_metadata(component)
        metadata = @data['metadata']
        return unless metadata.is_a?(Hash) && metadata.any?

        component.create_component_metadata!(data: metadata)
      end

      def restore_timestamps(component)
        updates = {}
        updates[:created_at] = Time.zone.parse(@data['created_at']) if @data['created_at']
        updates[:updated_at] = Time.zone.parse(@data['updated_at']) if @data['updated_at']
        component.update_columns(updates) if updates.any? # rubocop:disable Rails/SkipsModelValidations -- restoring original timestamps from backup
      end
    end
  end
end
