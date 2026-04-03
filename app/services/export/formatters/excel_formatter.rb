# frozen_string_literal: true

module Export
  module Formatters
    # Generates Excel workbooks using caxlsx.
    # Supports single-sheet (via generate) and multi-sheet (via generate_workbook).
    #
    # Multi-sheet mode is used by Export::Base when exporting projects with
    # multiple components — each component becomes one worksheet.
    #
    # Features:
    # - Appends a "Source" column (Direct/Inherited) from row_sources metadata
    # - Inherited rows get grey background + locked cells
    # - Direct rows are unlocked for editing
    # - Data validation dropdowns on Status, Severity, and Source columns
    # - Sheet protection enforces cell locks while allowing filter/sort
    # - Auto-filter on header row for easy filtering by Source
    class ExcelFormatter < BaseFormatter
      SOURCE_HEADER = 'Source'
      INHERITED_VALUE = 'Inherited'
      DIRECT_VALUE = 'Direct'

      # Columns that get dropdown validation: header name → allowed values
      DROPDOWN_COLUMNS = {
        'Status' => RuleConstants::STATUSES,
        'Severity' => RuleConstants::SEVERITIES_MAP.values, # CAT I, CAT II, CAT III
        SOURCE_HEADER => [DIRECT_VALUE, INHERITED_VALUE]
      }.freeze

      # Maps export column headers to field_editable? keys for per-cell lock styling.
      # Headers not in this map are considered read-only (always locked).
      HEADER_TO_FIELD = {
        'Requirement' => :title,
        'VulDiscussion' => :vuln_discussion,
        'Status' => :status,
        'Check' => :check_content,
        'Fix' => :fixtext,
        'Severity' => :rule_severity,
        'Artifact Description' => :artifact_description,
        'Status Justification' => :status_justification,
        'Vendor Comments' => :vendor_comments
      }.freeze

      # Single-sheet output. Wraps generate_workbook with a default sheet name.
      def generate(headers:, rows:)
        generate_workbook(sheets: [{ name: 'Sheet1', headers: headers, rows: rows }])
      end

      # Multi-sheet workbook. Each entry in sheets is { name:, headers:, rows: }.
      # Optional: row_sources: array of "Direct"/"Inherited" per row.
      # Returns the xlsx binary string.
      def generate_workbook(sheets:)
        package = Axlsx::Package.new
        package.use_shared_strings = true

        sheets.each do |sheet|
          build_worksheet(package, sheet)
        end

        package.to_stream.read
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

      private

      def build_worksheet(package, sheet)
        styles = package.workbook.styles
        header_style = styles.add_style(b: true, alignment: { wrap_text: true })
        editable_style = styles.add_style(alignment: { wrap_text: true }, locked: false)
        locked_style = styles.add_style(alignment: { wrap_text: true }, locked: true, bg_color: 'D9D9D9')

        row_sources = sheet[:row_sources]
        row_rules = sheet[:row_rules]
        has_sources = row_sources.is_a?(Array) && row_sources.any?

        # Append Source header when metadata is provided
        all_headers = has_sources ? sheet[:headers] + [SOURCE_HEADER] : sheet[:headers]
        last_col_letter = ('A'.ord + all_headers.size - 1).chr

        package.workbook.add_worksheet(name: sheet[:name]) do |ws|
          ws.add_row(all_headers, style: header_style, types: Array.new(all_headers.size, :string))

          sheet[:rows].each_with_index do |row, idx|
            source = has_sources ? row_sources[idx] : nil
            rule = row_rules.is_a?(Array) ? row_rules[idx] : nil

            row_data = has_sources ? row + [source] : row
            cell_styles = build_cell_styles(all_headers, rule, editable_style, locked_style)

            ws.add_row(
              row_data.map(&:to_s),
              types: Array.new(row_data.size, :string),
              style: cell_styles
            )
          end

          # Auto-filter on header row
          ws.auto_filter = "A1:#{last_col_letter}1" if sheet[:rows].any?

          # Data validation dropdowns
          add_data_validations(ws, all_headers, sheet[:rows].size)

          # Sheet protection: enforces locked cells, allows sort/filter
          ws.sheet_protection do |protection|
            protection.sort = false        # allow sorting
            protection.auto_filter = false # allow filtering
          end
        end
      end

      # Returns an array of styles per cell: editable or locked based on rule state.
      def build_cell_styles(headers, rule, editable_style, locked_style)
        headers.map do |header|
          field = HEADER_TO_FIELD[header]
          if rule && field
            rule.field_editable?(field) ? editable_style : locked_style
          else
            locked_style # Read-only columns (SRG fields, IDs) and Source are always locked
          end
        end
      end

      def add_data_validations(worksheet, headers, row_count)
        return if row_count.zero?

        headers.each_with_index do |header, col_idx|
          allowed = DROPDOWN_COLUMNS[header]
          next unless allowed

          col_letter = ('A'.ord + col_idx).chr
          range = "#{col_letter}2:#{col_letter}#{row_count + 1}"
          formula = "\"#{allowed.join(', ')}\""

          worksheet.add_data_validation(range,
                                        type: :list,
                                        formula1: formula,
                                        showErrorMessage: true,
                                        errorTitle: header,
                                        error: "Allowed values: #{allowed.join(', ')}",
                                        errorStyle: :stop,
                                        showInputMessage: true,
                                        promptTitle: header,
                                        prompt: "Select a #{header.downcase}")
        end
      end
    end
  end
end
