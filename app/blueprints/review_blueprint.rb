# frozen_string_literal: true

# Replaces Review#as_json which added `methods: [:name]`.
# The current Rule#as_json further strips user_id, rule_id, updated_at.
class ReviewBlueprint < Blueprinter::Base
  identifier :id

  fields :action, :comment, :created_at, :triage_status, :triage_set_at, :adjudicated_at

  # Delegated from user — avoids N+1 when user is eager-loaded
  field :name do |review, _options|
    review.user&.name
  end

  # PR-717 review remediation .8 — display-layer attribution. The display
  # methods on Review fall back to imported_email/name when the original
  # User can't be resolved on this instance (cross-instance JSON archive
  # restore). `*_imported` is the boolean Vue uses to render an "imported"
  # badge next to the name.
  field :triager_display_name do |review, _options|
    review.triager_display_name
  end
  field :triager_imported do |review, _options|
    review.triager_imported?
  end
  field :adjudicator_display_name do |review, _options|
    review.adjudicator_display_name
  end
  field :adjudicator_imported do |review, _options|
    review.adjudicator_imported?
  end

  # PR-717 review remediation .j4a step C1 — commenter attribution
  # display. Same fallback pattern (resolved User → imported_name →
  # imported_email → nil) used by triager/adjudicator. Frontend renders
  # an "imported" badge when commenter_imported is true.
  field :commenter_display_name do |review, _options|
    review.commenter_display_name
  end
  field :commenter_imported do |review, _options|
    review.commenter_imported?
  end
end
