# frozen_string_literal: true

module Import
  module JsonArchive
    # Validates the manifest.json from a backup archive.
    # Checks format version, SRG dependencies, and name conflicts.
    class ManifestValidator
      # 1.0 — original format (second-precision review timestamps).
      # 1.1 — microsecond-precision review created_at/updated_at + the
      #       compatible matcher path.
      SUPPORTED_VERSIONS = %w[1.0 1.1].freeze

      def initialize(manifest, project, component_filter: nil, dry_run: false)
        @manifest = manifest
        @project = project
        @component_filter = component_filter
        @dry_run = dry_run
      end

      def validate(result)
        validate_format_version(result)
        validate_components_present(result)
        return result unless result.success?

        validate_srg_dependencies(result)
        validate_no_name_conflicts(result)
        result
      end

      private

      def validate_format_version(result)
        version = @manifest['backup_format_version']
        return if SUPPORTED_VERSIONS.include?(version)

        result.add_error("Unsupported backup format version: #{version}. Supported: #{SUPPORTED_VERSIONS.join(', ')}")
      end

      def validate_components_present(result)
        components = @manifest['components']
        return if components.is_a?(Array) && components.any?

        result.add_error('Manifest contains no components')
      end

      def validate_srg_dependencies(result)
        archive_has_srgs = @manifest['srgs'].is_a?(Array) && @manifest['srgs'].any?

        @manifest['components'].each do |entry|
          srg_id = entry['srg_id']
          srg_version = entry['srg_version']
          next if srg_id.blank?

          srg = SecurityRequirementsGuide.find_by(srg_id: srg_id, version: srg_version)
          next if srg

          # If archive includes SRGs, they'll be auto-imported — not an error
          next if archive_has_srgs && @manifest['srgs'].any? { |s| s['srg_id'] == srg_id }

          # Try without version match
          srg_any_version = SecurityRequirementsGuide.find_by(srg_id: srg_id)
          if srg_any_version
            result.add_warning(
              "SRG '#{entry['srg_title']}' found but version mismatch: " \
              "archive has #{srg_version}, system has #{srg_any_version.version}"
            )
          else
            result.add_error(
              "Required SRG not found: #{entry['srg_title']} (#{srg_id}). " \
              'Please import the SRG before restoring this backup.'
            )
          end
        end

        validate_secondary_sources(result, archive_has_srgs)
      end

      # Dual-lineage components list their full source set per entry. A
      # missing based_on is the error above — nothing to build without it. A
      # missing SECONDARY costs one lineage link while the rest restores, so
      # it surfaces here as a pre-flight warning instead of a post-build
      # surprise. Restore-time resolution falls back across releases, so
      # only a wholly-absent SRG warrants the warning.
      def validate_secondary_sources(result, archive_has_srgs)
        @manifest['components'].each do |entry|
          sources = entry['source_srgs']
          next unless sources.is_a?(Array)

          sources.each do |source|
            source_id = source['srg_id']
            next if source_id.blank? || source_id == entry['srg_id']
            next if SecurityRequirementsGuide.exists?(srg_id: source_id)
            next if archive_has_srgs && @manifest['srgs'].any? { |s| s['srg_id'] == source_id }

            result.add_warning(
              "Source SRG '#{source['title']}' (#{source_id}) not found — the component " \
              'will restore without that lineage link. Import the SRG first for full lineage.'
            )
          end
        end
      end

      def validate_no_name_conflicts(result)
        @manifest['components'].each do |entry|
          existing = @project.components.find_by(name: entry['name'])
          next unless existing

          # During dry-run or with component_filter, conflicts are warnings (user can deselect/rename)
          if @component_filter || @dry_run
            result.add_warning(
              "Component name conflict: '#{entry['name']}' already exists in project '#{@project.name}'."
            )
          else
            result.add_error(
              "Component name conflict: '#{entry['name']}' already exists in project '#{@project.name}'. " \
              'Rename or delete the existing component before importing.'
            )
          end
        end
      end
    end
  end
end
