# frozen_string_literal: true

# Stop rails from wrapping elements fields that have errors with
# a field_with_errors class.

ActionView::Base.field_error_proc = proc do |html_tag, _instance|
  html_tag.html_safe # rubocop:disable Rails/OutputSafety
end
