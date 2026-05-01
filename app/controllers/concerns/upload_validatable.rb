# frozen_string_literal: true

# Shared upload validation for file size and content type.
# Include in controllers that accept file uploads, then use before_action.
#
# Example:
#   include UploadValidatable
#   before_action -> { validate_upload(:file, max_size: 50.megabytes, allowed_types: %w[.xml]) }, only: :create
#
module UploadValidatable
  extend ActiveSupport::Concern

  private

  # Validates an uploaded file's size and extension.
  # Renders 422 JSON and halts if validation fails.
  def validate_upload(param_name, max_size:, allowed_types: nil)
    file = params[param_name]
    return if file.blank? # let controller's own require/presence check handle missing files

    validate_upload_size(file, max_size) && validate_upload_type(file, allowed_types)
  end

  def validate_upload_size(file, max_size) # rubocop:disable Naming/PredicateMethod
    return true if file.size <= max_size

    render json: {
      toast: {
        title: 'Upload rejected',
        message: "File exceeds maximum size of #{ActiveSupport::NumberHelper.number_to_human_size(max_size)}.",
        variant: 'danger'
      }
    }, status: :unprocessable_content
    false
  end

  def validate_upload_type(file, allowed_types) # rubocop:disable Naming/PredicateMethod
    return true if allowed_types.blank?

    ext = File.extname(file.original_filename).downcase
    return true if allowed_types.include?(ext)

    render json: {
      toast: {
        title: 'Upload rejected',
        message: "Invalid file type '#{ext}'. Allowed: #{allowed_types.join(', ')}.",
        variant: 'danger'
      }
    }, status: :unprocessable_content
    false
  end
end
