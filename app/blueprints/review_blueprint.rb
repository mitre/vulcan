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

  # PR-717 review remediation .8 + .j4a C1 — display-layer attribution
  # for triager / adjudicator / commenter. See app/blueprints/
  # imported_attribution_fields.rb for the macro implementation
  # (top-level, NOT under concerns/ — only app/models/concerns and
  # app/controllers/concerns are Rails-special skip-namespace autoload
  # paths; placing the helper under app/blueprints/concerns would force
  # a Concerns:: prefix and break Zeitwerk constant resolution). The
  # three declarations below replace six hand-written `field` blocks.
  extend ImportedAttributionFields

  attribution_fields :triager
  attribution_fields :adjudicator
  attribution_fields :commenter
end
