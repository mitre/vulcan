# frozen_string_literal: true

# Shared export logic for controllers that support file exports.
# Delegates to Export::Base service for mode+format resolution.
module Exportable
  extend ActiveSupport::Concern

  private

  # Perform an export using the service layer.
  #
  # @param exportable [Component, Project, Array<Component>] the object(s) to export
  # @param mode [Symbol] export mode (:working_copy, :vendor_submission, etc.)
  # @param format [Symbol] output format (:csv, :excel, :xccdf, :inspec)
  # @param component_ids [Array<Integer>, nil] optional component ID filter (projects only)
  # @param filename [String, nil] override the default filename
  # @param zip_filename [String, nil] override the default zip filename (multi-component)
  def perform_export(exportable:, mode:, format:, component_ids: nil, filename: nil, zip_filename: nil,
                     formatter_options: {})
    result = Export::Base.new(
      exportable: exportable,
      mode: mode,
      format: format,
      component_ids: component_ids,
      zip_filename: zip_filename,
      formatter_options: formatter_options
    ).call

    send_data result.data, filename: filename || result.filename, type: result.content_type
  end
end
