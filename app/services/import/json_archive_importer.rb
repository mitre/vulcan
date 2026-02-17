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
    def initialize(zip_file:, project:, dry_run: false, include_reviews: true)
      @zip_file = zip_file
      @project = project
      @dry_run = dry_run
      @include_reviews = include_reviews
    end

    def call
      result = Result.new

      archive = parse_archive(result)
      return result unless result.success?

      manifest = archive[:manifest]
      JsonArchive::ManifestValidator.new(manifest, @project).validate(result)
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
      archive = { components: [] }

      begin
        Zip::File.open_buffer(read_file_data) do |zip|
          manifest_entry = zip.find_entry('manifest.json')
          unless manifest_entry
            result.add_error('Invalid backup archive: manifest.json not found')
            return archive
          end

          archive[:manifest] = JSON.parse(zip.read('manifest.json'))
          archive[:project] = safe_parse_json(zip, 'project.json')

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
      fallback = nil
      zip.entries.each do |entry|
        return entry.name.match(%r{\Acomponents/[^/]+/})[0] if entry.name.start_with?(prefix)

        fallback = entry.name.sub('component.json', '') if fallback.nil? && entry.name.match?(%r{\Acomponents/[^/]+/component\.json\z})
      end

      fallback
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
      ActiveRecord::Base.transaction do
        import_components(archive, result)
        result.merge_summary(dry_run: true)
        raise ActiveRecord::Rollback
      end
    end

    def perform_import(archive, result)
      ActiveRecord::Base.transaction do
        import_components(archive, result)

        raise ActiveRecord::Rollback unless result.success?
      end
    end

    def import_components(archive, result)
      total_rules = 0
      total_satisfactions = 0
      total_reviews = 0

      archive[:components].each do |comp_data|
        component = JsonArchive::ComponentBuilder.new(comp_data[:component], @project, result).build
        next unless component

        rule_id_map = JsonArchive::RuleBuilder.new(comp_data[:rules], component, result).build_all
        total_rules += rule_id_map.size

        satisfaction_count = JsonArchive::SatisfactionBuilder.new(
          comp_data[:satisfactions], rule_id_map, result
        ).build_all
        total_satisfactions += satisfaction_count

        next unless @include_reviews

        review_count = JsonArchive::ReviewBuilder.new(
          comp_data[:reviews], rule_id_map, result
        ).build_all
        total_reviews += review_count
      end

      result.merge_summary(
        components_imported: archive[:components].size,
        rules_imported: total_rules,
        satisfactions_imported: total_satisfactions,
        reviews_imported: total_reviews
      )
    end
  end
end
