# frozen_string_literal: true

require 'zip'
require 'json'

module Export
  module Formatters
    # Generates a ZIP archive containing JSON files that preserve 100% of
    # the component/rule object graph. Used for full-fidelity backup/restore.
    #
    # Archive structure:
    #   manifest.json
    #   project.json (when exporting from a project)
    #   components/
    #     ComponentName-V1R1/
    #       component.json
    #       rules.json
    #       satisfactions.json
    #       reviews.json
    #
    # Batch-capable: multi-component exports produce a single archive.
    class JsonArchiveFormatter < BaseFormatter
      def component_based?
        true
      end

      def batch_generate?
        true
      end

      # Single component export.
      def generate_from_component(component:, rules:)
        serializer = Serializers::BackupSerializer.new(component, preloaded_rules: rules)
        data = serializer.serialize

        Zip::OutputStream.write_buffer do |zio|
          write_manifest(zio, [serializer.manifest_entry])
          write_component_files(zio, component, data, '')
        end.string
      end

      # Multi-component export (project-level backup).
      # @param include_srg [Boolean] when true, include base SRG XML files in the archive
      def generate_batch(component_rule_pairs:, include_srg: false)
        serializers = component_rule_pairs.map do |pair|
          Serializers::BackupSerializer.new(pair[:component], preloaded_rules: pair[:rules])
        end

        manifest_entries = serializers.map(&:manifest_entry)
        srg_entries = include_srg ? collect_unique_srgs(component_rule_pairs) : []

        Zip::OutputStream.write_buffer do |zio|
          write_manifest(zio, manifest_entries, srg_entries: srg_entries)
          write_project_json(zio, component_rule_pairs.first[:component].project)
          write_srg_files(zio, srg_entries) if srg_entries.any?

          component_rule_pairs.each_with_index do |pair, idx|
            component = pair[:component]
            data = serializers[idx].serialize
            dir = component_dir_name(component)
            write_component_files(zio, component, data, dir)
          end
        end.string
      end

      def content_type
        'application/zip'
      end

      def file_extension
        '-backup.zip'
      end

      private

      def write_manifest(zio, component_entries, srg_entries: [])
        manifest = {
          backup_format_version: Serializers::BackupSerializer::BACKUP_FORMAT_VERSION,
          vulcan_version: vulcan_version,
          exported_at: Time.current.iso8601,
          components: component_entries
        }
        manifest[:srgs] = srg_entries.map { |s| s.except(:xml) } if srg_entries.any?
        zio.put_next_entry('manifest.json')
        zio.write(JSON.pretty_generate(manifest))
      end

      def write_project_json(zio, project)
        return unless project

        project_data = {
          name: project.name,
          description: project.description,
          visibility: project.visibility,
          metadata: project.project_metadata&.data,
          memberships: serialize_memberships(project)
        }
        zio.put_next_entry('project.json')
        zio.write(JSON.pretty_generate(project_data))
      end

      def write_component_files(zio, _component, data, dir)
        prefix = dir.empty? ? '' : "components/#{dir}"

        zio.put_next_entry("#{prefix}component.json")
        zio.write(JSON.pretty_generate(data[:component]))

        zio.put_next_entry("#{prefix}rules.json")
        zio.write(JSON.pretty_generate(data[:rules]))

        zio.put_next_entry("#{prefix}satisfactions.json")
        zio.write(JSON.pretty_generate(data[:satisfactions]))

        zio.put_next_entry("#{prefix}reviews.json")
        zio.write(JSON.pretty_generate(data[:reviews]))
      end

      def component_dir_name(component)
        version = component.version ? "V#{component.version}" : ''
        release = component.release ? "R#{component.release}" : ''
        "#{component.name.tr(' ', '-')}-#{version}#{release}/"
      end

      def serialize_memberships(project)
        project.memberships.where(membership_type: 'Project').includes(:user).map do |m|
          { email: m.user.email, name: m.user.name, role: m.role }
        end
      end

      def collect_unique_srgs(component_rule_pairs)
        # Collect unique SRG IDs from components, then load full records (including xml column)
        srg_ids = component_rule_pairs.filter_map { |p| p[:component].security_requirements_guide_id }.uniq
        srgs = SecurityRequirementsGuide.where(id: srg_ids).index_by(&:id)

        seen = {}
        component_rule_pairs.each do |pair|
          srg = srgs[pair[:component].security_requirements_guide_id]
          next unless srg

          key = [srg.srg_id, srg.version]
          next if seen.key?(key)

          filename = "#{srg.title.tr(' ', '_').gsub(/[^A-Za-z0-9_-]/, '')}-#{srg.version}.xml"
          seen[key] = {
            srg_id: srg.srg_id,
            title: srg.title,
            version: srg.version,
            filename: filename,
            xml: srg.xml
          }
        end
        seen.values
      end

      def write_srg_files(zio, srg_entries)
        srg_entries.each do |entry|
          zio.put_next_entry("srgs/#{entry[:filename]}")
          zio.write(entry[:xml])
        end
      end

      def vulcan_version
        Rails.application.class.module_parent.const_defined?(:VERSION) ? Rails.application.class.module_parent::VERSION : 'unknown'
      rescue StandardError
        'unknown'
      end
    end
  end
end
