# frozen_string_literal: true

module Export
  # Value object representing the output of an export operation.
  # Carries the file data, filename, and MIME content type.
  Result = Struct.new(:data, :filename, :content_type, keyword_init: true)
end
