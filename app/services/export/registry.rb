# frozen_string_literal: true

module Export
  # Maps valid (mode, format) combinations to implementing classes.
  # Single source of truth for what exports are supported.
  class Registry
    class InvalidCombination < StandardError; end

    # Valid combinations matrix — only these pairs are allowed.
    # Keys are mode symbols, values are arrays of format symbols.
    COMBINATIONS = {
      working_copy: %i[csv excel],
      vendor_submission: %i[excel],
      published_stig: %i[xccdf inspec],
      backup: %i[xccdf]
    }.freeze

    MODE_CLASSES = {
      working_copy: 'Export::Modes::WorkingCopy',
      vendor_submission: 'Export::Modes::VendorSubmission',
      published_stig: 'Export::Modes::PublishedStig',
      backup: 'Export::Modes::Backup'
    }.freeze

    FORMATTER_CLASSES = {
      csv: 'Export::Formatters::CsvFormatter',
      excel: 'Export::Formatters::ExcelFormatter',
      xccdf: 'Export::Formatters::XccdfFormatter',
      inspec: 'Export::Formatters::InspecFormatter'
    }.freeze

    class << self
      def valid?(mode, format)
        COMBINATIONS.fetch(mode, []).include?(format)
      end

      def mode_class(mode)
        class_name = MODE_CLASSES[mode]
        raise InvalidCombination, "Unknown mode: #{mode}" unless class_name

        class_name.constantize
      end

      def formatter_class(format)
        class_name = FORMATTER_CLASSES[format]
        raise InvalidCombination, "Unknown format: #{format}" unless class_name

        class_name.constantize
      end

      def formats_for(mode)
        COMBINATIONS.fetch(mode, [])
      end
    end
  end
end
