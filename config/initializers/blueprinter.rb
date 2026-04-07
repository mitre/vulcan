# frozen_string_literal: true

# Blueprinter JSON serializer configuration.
#
# Blueprinter replaces the model-level `as_json` overrides with dedicated
# serializer classes (one per model, with named views for different contexts).
# This follows the GitLab/Discourse pattern of separating serialization
# from domain models — see https://thoughtbot.com/blog/better-serialization-less-as-json
#
# Usage:
#   RuleBlueprint.render(rule, view: :editor)
#   ComponentBlueprint.render(component, view: :show)
#   StigBlueprint.render_as_hash(stigs, view: :index)  # returns hash, no JSON string
#
# Explicitly activate Oj Rails compatibility before Blueprinter uses it.
# Suppresses "Oj::Rails.mimic_JSON was called implicitly" warning.
Oj.mimic_JSON

Blueprinter.configure do |config|
  # Use Oj for ~2x faster JSON generation vs stdlib JSON.
  config.generator = Oj

  # Sort fields by definition order (as declared in the blueprint class).
  # Makes output match the blueprint's declared field order for readability.
  config.sort_fields_by = :definition

  # Automatic N+1 prevention: the blueprinter-activerecord extension
  # inspects each blueprint's associations and calls includes/preload
  # on the ActiveRecord::Relation before serialization.
  config.extensions << BlueprinterActiveRecord::Preloader.new(auto: true)
end
