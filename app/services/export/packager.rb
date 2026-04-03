# frozen_string_literal: true

require 'zip'

module Export
  # Handles single-file vs multi-file (zip) packaging.
  # Single result = passthrough.
  # Multiple results = zip archive.
  class Packager
    class << self
      def package(results, zip_filename: 'export.zip')
        return results.first if results.size == 1

        zip_data = Zip::OutputStream.write_buffer do |zio|
          results.each do |result|
            zio.put_next_entry(result.filename)
            zio.write(result.data)
          end
        end

        Result.new(
          data: zip_data.string,
          filename: zip_filename,
          content_type: 'application/zip'
        )
      end
    end
  end
end
