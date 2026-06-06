# frozen_string_literal: true

require 'json'
require 'zip'

module Import
  module JsonArchive
    module Merge
      # Normalized input to the Analyzer. Accepts the four sources we merge
      # from — a parsed single-component slice, a spreadsheet, a live
      # component, or a zip archive on disk — and produces a uniform shape
      # of string-keyed Hashes for downstream pure-computation classes.
      #
      # Per F19/F20 in the expert review, this is a class (not a plain
      # Struct) so construction validates format and shape; bad inputs fail
      # at the boundary, not deep inside the Analyzer pipeline.
      class MergeInput
        VALID_FORMATS = %i[json_archive spreadsheet component].freeze

        attr_reader :format, :component_meta, :rules, :reviews,
                    :satisfactions, :memberships, :manifest

        # @param archive_data [Hash] a single-component slice in the
        #   BackupSerializer shape: { component:, rules:, satisfactions:,
        #   reviews: }. Symbol or string keys accepted.
        def self.from_json_archive(archive_data, manifest: nil, memberships: nil)
          stringified = archive_data.deep_stringify_keys
          raise ArgumentError, 'archive_data missing required "component" key' unless stringified.key?('component')

          new(
            format: :json_archive,
            component_meta: stringified['component'].to_h,
            rules: Array(stringified['rules']),
            reviews: Array(stringified['reviews']),
            satisfactions: Array(stringified['satisfactions']),
            memberships: memberships,
            manifest: manifest || default_manifest
          )
        end

        # @param parsed_rows [Array<Hash>] rows as Roo produces them (string keys)
        # @param component [Component] the target component (provides meta only)
        def self.from_spreadsheet(parsed_rows, component:)
          normalized = SpreadsheetParser.normalize_header_aliases(parsed_rows.map(&:to_h))

          new(
            format: :spreadsheet,
            component_meta: {
              'name' => component.name,
              'prefix' => component.prefix,
              'version' => component.version,
              'release' => component.release
            },
            rules: normalized,
            reviews: [],
            satisfactions: [],
            memberships: nil,
            manifest: default_manifest
          )
        end

        # Round-trip a live component through BackupSerializer to get a
        # canonical archive-shape input. Acceptable for Phase 1; the
        # Phase 2 orchestrator avoids the round-trip by passing already
        # eager-loaded records to the Analyzer directly.
        def self.from_component(component)
          serializer = Export::Serializers::BackupSerializer.new(component)
          from_json_archive(serializer.serialize)
        end

        # @param path [String] absolute path to a backup zip
        # @param component_dir [String, nil] subdirectory under components/
        #   to read in a multi-component archive; nil = single (flat) layout
        def self.from_zip_path(path, component_dir: nil)
          entries = read_zip_entries(path)
          prefix = locate_component_prefix(entries, component_dir)

          raise ArgumentError, "zip archive has no component.json (looked under #{prefix.inspect})" unless entries.key?("#{prefix}component.json")

          manifest = entries['manifest.json'] ? JSON.parse(entries['manifest.json']) : default_manifest
          memberships = parse_memberships(entries['project.json'])

          archive_data = {
            'component' => JSON.parse(entries["#{prefix}component.json"]),
            'rules' => parse_optional_json(entries["#{prefix}rules.json"]),
            'satisfactions' => parse_optional_json(entries["#{prefix}satisfactions.json"]),
            'reviews' => parse_optional_json(entries["#{prefix}reviews.json"])
          }

          from_json_archive(archive_data, manifest: manifest, memberships: memberships)
        end

        # Locate the component prefix in a zip's entry-name set. Flat
        # layout has component.json at root; nested layout has it under
        # components/<dir>/.
        def self.locate_component_prefix(entries, requested_dir)
          return "components/#{requested_dir}/" if requested_dir
          return '' if entries.key?('component.json')

          component_dirs = entries.keys.filter_map do |name|
            match = name.match(%r{\Acomponents/([^/]+)/component\.json\z})
            match && match[1]
          end
          return "components/#{component_dirs.first}/" if component_dirs.size == 1

          # Zero matches → caller error surfaces via the missing-key check below.
          # Multiple matches → caller must disambiguate with component_dir:.
          if component_dirs.size > 1
            raise ArgumentError,
                  "multi-component archive — pass component_dir: (found #{component_dirs.inspect})"
          end

          ''
        end

        def self.default_manifest
          { 'backup_format_version' => Export::Serializers::BackupSerializer::BACKUP_FORMAT_VERSION }
        end

        def self.read_zip_entries(path)
          entries = {}
          Zip::File.open(path) do |zip|
            zip.each { |e| entries[e.name] = e.get_input_stream.read unless e.directory? }
          end
          entries
        end

        def self.parse_optional_json(content)
          return [] if content.blank?

          JSON.parse(content)
        end

        def self.parse_memberships(content)
          return nil if content.blank?

          parsed = JSON.parse(content)
          parsed.is_a?(Hash) ? parsed['memberships'] : nil
        end

        private_class_method :default_manifest, :read_zip_entries,
                             :parse_optional_json, :parse_memberships

        def initialize(format:, component_meta:, rules: [], reviews: [], satisfactions: [],
                       memberships: nil, manifest: nil)
          raise ArgumentError, "unknown format: #{format.inspect}" unless VALID_FORMATS.include?(format)
          raise ArgumentError, 'component_meta required' if component_meta.nil?

          @format = format
          @component_meta = component_meta
          @rules = rules || []
          @reviews = reviews || []
          @satisfactions = satisfactions || []
          @memberships = memberships
          @manifest = manifest || self.class.send(:default_manifest)
        end
      end
    end
  end
end
