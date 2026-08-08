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

        phase, reason = normalize_comment_phase(@data['comment_phase'], @data['closed_reason'])

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
          # Legacy archives predate the authoring-profile discriminator —
          # every pre-existing archive is a STIG.
          document_type: @data['document_type'] || 'stig',
          security_requirements_guide_id: srg.id,
          # Legacy archives (draft / adjudication / final) are remapped
          # to the current open/closed shape via #normalize_comment_phase.
          comment_phase: phase,
          closed_reason: reason,
          comment_period_starts_at: @data['comment_period_starts_at'],
          comment_period_ends_at: @data['comment_period_ends_at']
        )
        component.skip_import_srg_rules = true

        resolve_overlay_parent(component)
        resolve_source_srgs(component)
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

      # Map any combination of legacy four-value comment_phase + new
      # closed_reason into the current two-value shape. Returns
      # [phase, reason]. Defaults to [open, nil] when both are absent.
      def normalize_comment_phase(legacy_phase, legacy_reason)
        case legacy_phase
        when 'draft', nil, ''
          ['open', nil]
        when 'adjudication'
          %w[closed adjudicating]
        when 'final'
          %w[closed finalized]
        when 'closed'
          ['closed', legacy_reason.presence]
        else
          [legacy_phase, legacy_reason.presence]
        end
      end

      def resolve_srg
        based_on = @data['based_on']
        return nil unless based_on

        srg = find_catalog_srg(based_on['srg_id'], based_on['version'])

        @result.add_error("Cannot find SRG: #{based_on['title']} (#{based_on['srg_id']})") unless srg

        srg
      end

      # Match the destination catalog on the exact release first, then fall
      # back to any release of the same SRG — a restore target may carry a
      # different release than the source instance did.
      def find_catalog_srg(srg_id, version)
        SecurityRequirementsGuide.find_by(srg_id: srg_id, version: version) ||
          SecurityRequirementsGuide.find_by(srg_id: srg_id)
      end

      # Rebuild the declared parent set. Assigning before save is deliberate:
      # the membership and eligibility validations must see these rows on the
      # component's first save. based_on is added by the model's own
      # reconciliation, so only the remaining sources matter here.
      #
      # A missing secondary is a warning, not an error: unlike based_on, whose
      # absence leaves no component to build, a missing secondary costs one
      # lineage link and the rest of the component still restores intact.
      def resolve_source_srgs(component)
        entries = @data['source_srgs']
        # Archives written before multi-parent support have no such key, and
        # an archive is external input that may carry a malformed value —
        # anything but an array falls back to the based_on reconciliation
        # alone, the same tolerant posture build_additional_questions takes.
        return unless entries.is_a?(Array)

        component.declared_source_srg_ids = entries.filter_map { |entry| catalog_id_for_source(entry) }
      end

      def catalog_id_for_source(entry)
        srg = find_catalog_srg(entry['srg_id'], entry['version'])
        return srg.id if srg

        @result.add_warning(
          "Source SRG '#{entry['title']}' (#{entry['srg_id']}) not found. " \
          'Imported without that lineage link.'
        )
        nil
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
