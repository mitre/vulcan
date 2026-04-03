# frozen_string_literal: true

module Import
  module JsonArchive
    # Imports SRG XML files from a backup archive into the target system.
    # Skips SRGs that already exist (matched by srg_id + version).
    class SrgImporter
      # @param manifest_srgs [Array<Hash>] srgs array from manifest.json
      # @param srg_files [Hash<String, String>] filename => XML content
      # @param result [Import::Result] accumulates warnings/errors
      def initialize(manifest_srgs:, srg_files:, result:)
        @manifest_srgs = manifest_srgs || []
        @srg_files = srg_files || {}
        @result = result
      end

      def import_all
        imported = 0

        @manifest_srgs.each do |entry|
          srg_id = entry['srg_id']
          version = entry['version']

          # Skip if already exists
          next if SecurityRequirementsGuide.exists?(srg_id: srg_id, version: version)

          xml = @srg_files[entry['filename']]
          unless xml
            @result.add_warning("SRG XML file '#{entry['filename']}' not found in archive, skipping import")
            next
          end

          import_srg(xml)
          imported += 1
        end

        imported
      end

      private

      def import_srg(xml)
        xml_string = xml.force_encoding('UTF-8')
        parsed = Xccdf::Benchmark.parse(xml_string)
        srg = SecurityRequirementsGuide.from_mapping(parsed)
        srg.parsed_benchmark = parsed
        srg.xml = xml_string
        srg.save!
      end
    end
  end
end
