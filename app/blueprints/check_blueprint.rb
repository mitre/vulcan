# frozen_string_literal: true

# Serializes Check records for rule detail views and editors.
class CheckBlueprint < Blueprinter::Base
  identifier :id

  fields :system, :content_ref_name, :content_ref_href, :content

  # Rails accepts_nested_attributes_for expects _destroy key
  field :_destroy do |_check, _options|
    false
  end
end
