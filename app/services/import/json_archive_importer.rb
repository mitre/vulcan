# frozen_string_literal: true

require 'zip'
require 'json'

module Import
  # Orchestrator for importing a JSON archive backup into a project.
  #
  # Usage:
  #   result = Import::JsonArchiveImporter.new(
  #     zip_file: uploaded_file,
  #     project: project,
  #     dry_run: false,
  #     include_reviews: true
  #   ).call
  #
  # Options:
  #   dry_run: true         — validate only, no records created (wraps in rolled-back transaction)
  #   include_reviews: true — import review history (default: true)
  class JsonArchiveImporter
    def initialize(zip_file:, project:, dry_run: false, include_reviews: true, include_memberships: false,
                   component_filter: nil, imported_by: nil)
      @zip_file = zip_file
      @project = project
      @dry_run = dry_run
      @include_reviews = include_reviews
      @include_memberships = include_memberships
      @component_filter = component_filter
      # PR-717 review remediation .10 — imported_by surfaces on the
      # Component-level audit row that ReviewBuilder writes per import.
      # When unset (controllers may not always pass it), the audit row
      # still records action + archive identifier + external_ids.
      @imported_by = imported_by
    end

    def call
      result = Result.new

      archive = parse_archive(result)
      return result unless result.success?

      manifest = archive[:manifest]
      JsonArchive::ManifestValidator.new(
        manifest, @project, component_filter: @component_filter, dry_run: @dry_run
      ).validate(result)
      return result unless result.success?

      if @dry_run
        perform_dry_run(archive, result)
      else
        perform_import(archive, result)
      end

      result
    end

    private

    def parse_archive(result)
      archive = { components: [], srg_files: {} }

      begin
        Zip::File.open_buffer(read_file_data) do |zip|
          # PR-717 review remediation .lsj — zip-bomb decompression
          # budget. Pre-fix, rubyzip's per-entry validation could pass
          # while the aggregate uncompressed size still expanded to
          # multiple GB (50-100 MB archive → 5+ GB on disk before OOM).
          # Sum entry.size (uncompressed bytes from the central directory
          # — no actual decompression) and reject before parsing if over
          # budget. Configurable via Settings.import.json_archive_size_budget_mb
          # (default 500 MB).
          budget_bytes = Settings.import.json_archive_size_budget_mb * 1.megabyte
          total = zip.entries.sum(&:size)
          if total > budget_bytes
            result.add_error(
              "Archive uncompressed size (#{(total / 1.megabyte.to_f).round(1)} MB) " \
              "exceeds decompression budget (#{Settings.import.json_archive_size_budget_mb} MB). " \
              'Refusing to decompress.'
            )
            return archive
          end

          manifest_entry = zip.find_entry('manifest.json')
          unless manifest_entry
            result.add_error('Invalid backup archive: manifest.json not found')
            return archive
          end

          archive[:manifest] = JSON.parse(zip.read('manifest.json'))
          archive[:project] = safe_parse_json(zip, 'project.json')

          # Parse SRG XML files from srgs/ directory
          zip.entries.each do |entry|
            next unless entry.name.start_with?('srgs/') && entry.name.end_with?('.xml')

            filename = entry.name.sub('srgs/', '')
            archive[:srg_files][filename] = zip.read(entry.name)
          end

          # Detect archive structure: flat (single component) or nested (components/ directory)
          archive[:components] = detect_and_parse_components(zip, archive[:manifest])
        end
      rescue Zip::Error => e
        result.add_error("Invalid ZIP file: #{e.message}")
      rescue JSON::ParserError => e
        result.add_error("Invalid JSON in archive: #{e.message}")
      end

      archive
    end

    def detect_and_parse_components(zip, manifest)
      # Check for flat structure (single component export)
      return [parse_component_files(zip, '')] if zip.find_entry('component.json')

      # Nested structure: components/ComponentName-V1R1/
      manifest['components'].filter_map do |entry|
        dir = find_component_dir(zip, entry)
        next unless dir

        parse_component_files(zip, dir)
      end
    end

    def find_component_dir(zip, manifest_entry)
      # Try to find the matching directory in the zip
      prefix = "components/#{manifest_entry['name'].tr(' ', '-')}-"
      match = zip.entries.find { |entry| entry.name.start_with?(prefix) }
      return match.name.match(%r{\Acomponents/[^/]+/})[0] if match

      fallback_entry = zip.entries.find { |entry| entry.name.match?(%r{\Acomponents/[^/]+/component\.json\z}) }
      fallback_entry&.name&.sub('component.json', '')
    end

    def parse_component_files(zip, dir)
      {
        component: safe_parse_json(zip, "#{dir}component.json") || {},
        rules: safe_parse_json(zip, "#{dir}rules.json") || [],
        satisfactions: safe_parse_json(zip, "#{dir}satisfactions.json") || [],
        reviews: safe_parse_json(zip, "#{dir}reviews.json") || []
      }
    end

    def safe_parse_json(zip, path)
      entry = zip.find_entry(path)
      return nil unless entry

      JSON.parse(zip.read(path))
    end

    def read_file_data
      case @zip_file
      when ActionDispatch::Http::UploadedFile, Rack::Test::UploadedFile
        @zip_file.read
      when StringIO
        @zip_file.string
      when String
        @zip_file
      else
        @zip_file.respond_to?(:read) ? @zip_file.read : @zip_file
      end
    end

    def perform_dry_run(archive, result)
      # Fast path: compute summary from parsed JSON without writing to DB
      component_details = archive[:components].map do |comp_data|
        name = comp_data[:component]['name']
        based_on = comp_data[:component]['based_on'] || {}
        {
          name: name,
          rule_count: comp_data[:rules].size,
          conflict: @project.components.exists?(name: name),
          srg_title: based_on['title'],
          srg_version: based_on['version']
        }
      end

      total_rules = archive[:components].sum { |c| c[:rules].size }
      total_satisfactions = archive[:components].sum { |c| c[:satisfactions].size }
      total_reviews = @include_reviews ? archive[:components].sum { |c| c[:reviews].size } : 0
      total_memberships = @include_memberships ? (archive.dig(:project, 'memberships')&.size || 0) : 0
      srg_details = srg_import_details(archive)

      result.merge_summary(
        dry_run: true,
        components_imported: archive[:components].size,
        rules_imported: total_rules,
        satisfactions_imported: total_satisfactions,
        reviews_imported: total_reviews,
        memberships_imported: total_memberships,
        srgs_imported: srg_details.size,
        srg_details: srg_details,
        component_details: component_details
      )
    end

    def perform_import(archive, result)
      ActiveRecord::Base.transaction do
        # Import SRGs first — components depend on them
        import_srgs(archive, result)
        return unless result.success?

        import_components(archive, result, manifest: archive[:manifest])

        raise ActiveRecord::Rollback unless result.success?
      end
    end

    def import_components(archive, result, manifest: nil)
      total_rules = 0
      total_satisfactions = 0
      total_reviews = 0
      imported_count = 0

      # Build component_details for preview (always computed from full archive)
      component_details = archive[:components].map do |comp_data|
        name = comp_data[:component]['name']
        based_on = comp_data[:component]['based_on'] || {}
        {
          name: name,
          rule_count: comp_data[:rules].size,
          conflict: @project.components.exists?(name: name),
          srg_title: based_on['title'],
          srg_version: based_on['version']
        }
      end

      archive[:components].each do |comp_data|
        comp_name = comp_data[:component]['name']

        # Apply component_filter: skip components not in filter keys
        if @component_filter
          next unless @component_filter.key?(comp_name)

          # Rename component if filter maps to a different name
          import_name = @component_filter[comp_name]
          comp_data[:component]['name'] = import_name if import_name != comp_name
        end

        component = JsonArchive::ComponentBuilder.new(comp_data[:component], @project, result).build
        next unless component

        imported_count += 1

        rule_id_map = JsonArchive::RuleBuilder.new(comp_data[:rules], component, result).build_all
        total_rules += rule_id_map.size

        satisfaction_count = JsonArchive::SatisfactionBuilder.new(
          comp_data[:satisfactions], rule_id_map, result
        ).build_all
        total_satisfactions += satisfaction_count

        next unless @include_reviews

        review_count = JsonArchive::ReviewBuilder.new(
          comp_data[:reviews], rule_id_map, result,
          component: component, manifest: manifest, imported_by: @imported_by
        ).build_all
        total_reviews += review_count
      end

      total_memberships = 0
      if @include_memberships
        memberships_data = archive.dig(:project, 'memberships') || []
        total_memberships = JsonArchive::MembershipBuilder.new(
          memberships_data, @project, result
        ).build_all
      end

      result.merge_summary(
        components_imported: imported_count,
        rules_imported: total_rules,
        satisfactions_imported: total_satisfactions,
        reviews_imported: total_reviews,
        memberships_imported: total_memberships,
        srgs_imported: @srgs_imported || 0,
        component_details: component_details
      )
    end

    def import_srgs(archive, result)
      manifest_srgs = archive.dig(:manifest, 'srgs') || []
      @srgs_imported = JsonArchive::SrgImporter.new(
        manifest_srgs: manifest_srgs,
        srg_files: archive[:srg_files],
        result: result
      ).import_all
    end

    def srg_import_details(archive)
      manifest_srgs = archive.dig(:manifest, 'srgs') || []
      manifest_srgs.filter_map do |entry|
        next if SecurityRequirementsGuide.exists?(srg_id: entry['srg_id'], version: entry['version'])

        { srg_id: entry['srg_id'], title: entry['title'], version: entry['version'] }
      end
    end
  end
end
