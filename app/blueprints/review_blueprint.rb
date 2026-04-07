# frozen_string_literal: true

# Replaces Review#as_json which added `methods: [:name]`.
# The current Rule#as_json further strips user_id, rule_id, updated_at.
class ReviewBlueprint < Blueprinter::Base
  identifier :id

  fields :action, :comment, :created_at

  # Delegated from user — avoids N+1 when user is eager-loaded
  field :name do |review, _options|
    review.user&.name
  end
end
