# frozen_string_literal: true

class CheckBlueprint < Blueprinter::Base
  identifier :id

  fields :system,
         :content_ref_name,
         :content_ref_href,
         :content
end
