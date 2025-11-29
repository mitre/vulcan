# frozen_string_literal: true

class ReviewBlueprint < Blueprinter::Base
  identifier :id

  fields :action,
         :comment,
         :created_at

  field :name do |review|
    review.user&.name
  end
end
