# frozen_string_literal: true

module Export
  module Formatters
    # Generates Excel workbooks using FastExcel.
    # Supports single-sheet (via generate) and multi-sheet (via generate_workbook).
    #
    # Multi-sheet mode is used by Export::Base when exporting projects with
    # multiple components — each component becomes one worksheet.
    class ExcelFormatter < BaseFormatter
      # Single-sheet output. Wraps generate_workbook with a default sheet name.
      def generate(headers:, rows:)
        generate_workbook(sheets: [{ name: 'Sheet1', headers: headers, rows: rows }])
      end

      # Multi-sheet workbook. Each entry in sheets is { name:, headers:, rows: }.
      # Returns the xlsx binary string.
      def generate_workbook(sheets:)
        workbook = FastExcel.open(constant_memory: true)

        sheets.each do |sheet|
          worksheet = workbook.add_worksheet(sheet[:name])
          worksheet.auto_width = true
          worksheet.append_row(sheet[:headers])

          last_row_num = 0
          sheet[:rows].each do |row|
            last_row_num += 1
            row.each_with_index do |value, col_index|
              worksheet.write_string(last_row_num, col_index, value.to_s, nil)
            end
          end
        end

        # MUST close before read_string in constant_memory mode.
        # close() finalizes the xlsx archive (ZIP central directory, flush).
        # read_string() then reads the completed temp file.
        workbook.close if workbook.is_open
        workbook.read_string
      end

      def multi_sheet?
        true
      end

      def content_type
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      end

      def file_extension
        '.xlsx'
      end
    end
  end
end
