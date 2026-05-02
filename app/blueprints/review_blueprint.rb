# frozen_string_literal: true

# Replaces Review#as_json which added `methods: [:name]`.
# Originally also stripped user_id/rule_id/updated_at to mirror
# Rule#as_json's pattern; PR-717 .20 brings rule_id back into the default
# field list (frontend modal needs it for picker scope after a triage
# mutation, otherwise it has to refetch). user_id stays excluded as a
# public-comment correlation guard.
class ReviewBlueprint < Blueprinter::Base
  identifier :id

  fields :action, :comment, :created_at, :triage_status, :triage_set_at, :adjudicated_at

  # PR-717 review remediation .20 — fields the frontend modal needs
  # to refresh in place after a triage/adjudicate/withdraw/update
  # mutation, eliminating the post-mutation refetch round trip.
  fields :rule_id, :section, :responding_to_review_id, :duplicate_of_review_id, :triage_set_by_id

  # Delegated from user — avoids N+1 when user is eager-loaded
  field :name do |review, _options|
    review.user&.name
  end

  # PR-717 review remediation .20 — explicit author_name. Frontend modal
  # uses `review.author_name` from the row hash; ReviewBlueprint output
  # had only :name. Expose both for stability across the API.
  field :author_name do |review, _options|
    review.user&.name
  end

  # PR-717 review remediation .20 — author_email is gated. Default
  # response omits it (a public-comment endpoint exposing every
  # commenter's email enables scraping during open comment windows).
  # Admin-tier surfaces (admin actions disclosure, disposition export)
  # opt in via `render_as_hash(review, include_email: true)`. Mirrors
  # the disposition-export include_email pattern in
  # app/lib/disposition_matrix_export.rb.
  field :author_email,
        if: ->(_field, _review, options) { options && options[:include_email] } do |review, _options|
    review.user&.email
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
