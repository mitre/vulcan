# frozen_string_literal: true

module Import
  module JsonArchive
    # Validates the manifest.json from a backup archive.
    # Checks format version, SRG dependencies, and name conflicts.
    class ManifestValidator
      SUPPORTED_VERSIONS = ['1.0'].freeze

      def initialize(manifest, project)
        @manifest = manifest
        @project = project
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
        @manifest['components'].each do |entry|
          srg_id = entry['srg_id']
          srg_version = entry['srg_version']
          next if srg_id.blank?

          srg = SecurityRequirementsGuide.find_by(srg_id: srg_id, version: srg_version)
          next if srg

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
      end

      def validate_no_name_conflicts(result)
        @manifest['components'].each do |entry|
          existing = @project.components.find_by(name: entry['name'])
          next unless existing

          result.add_error(
            "Component name conflict: '#{entry['name']}' already exists in project '#{@project.name}'. " \
            'Rename or delete the existing component before importing.'
          )
        end
      end
    end
  end
end
