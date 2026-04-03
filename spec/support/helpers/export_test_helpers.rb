# frozen_string_literal: true

# Shared helper methods for export specs.
# Eliminates duplicate read_xlsx/parse_data_rows/zip_entries/zip_read
# across multiple spec files.
module ExportTestHelpers
  # Read binary xlsx data into a Roo workbook
  def read_xlsx(binary_data)
    tmpfile = Tempfile.new(['test', '.xlsx'])
    tmpfile.binmode
    tmpfile.write(binary_data)
    tmpfile.close
    workbook = Roo::Spreadsheet.open(tmpfile.path)
    # Keep tmpfile reference alive so GC doesn't delete the file
    workbook.instance_variable_set(:@_tmpfile, tmpfile)
    workbook
  end

  # Parse data rows from xlsx sheet (skip header row)
  def parse_data_rows(workbook, sheet_index = 0)
    workbook.sheet(sheet_index).parse(headers: true).drop(1)
  end

  # List entry names from a zip binary string
  def zip_entries(data)
    entries = []
    Zip::File.open_buffer(StringIO.new(data)) { |zip| zip.each { |entry| entries << entry.name } }
    entries
  end

  # Read a specific entry from a zip binary string
  def zip_read(data, name)
    Zip::File.open_buffer(StringIO.new(data)) { |zip| return zip.read(name) }
  end
end

RSpec.configure do |config|
  config.include ExportTestHelpers
end
