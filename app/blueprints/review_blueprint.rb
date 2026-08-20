# frozen_string_literal: true

# Replaces Review#as_json which added `methods: [:name]`.
# Originally also stripped user_id/rule_id/updated_at to mirror
# Rule#as_json's pattern; rule_id is back in the default field list
# (the frontend modal needs it for picker scope after a triage
# mutation, otherwise it has to refetch). user_id stays excluded as a
# public-comment correlation guard.
class ReviewBlueprint < Blueprinter::Base
  identifier :id

  fields :action, :comment, :created_at, :triage_status, :triage_set_at, :adjudicated_at

  # fields the frontend modal needs
  # to refresh in place after a triage/adjudicate/withdraw/update
  # mutation, eliminating the post-mutation refetch round trip.
  fields :rule_id, :section, :responding_to_review_id, :duplicate_of_review_id,
         :addressed_by_rule_id, :triage_set_by_id, :commentable_type

  # Counts replies in memory once they are loaded; without the declaration this
  # asks the database for a count per comment, and a count never loads a record
  # so nothing else would reveal it.
  field :responses_count, preload: :responses do |review, _options|
    review.responses.size
  end

  # Reads a lookup the caller passes in; reaches nothing.
  field :rule_displayed_name do |review, options|
    rule_names = options[:rule_names] || {}
    rule_names[review.rule_id]
  end

  # Delegated from user — avoids N+1 when user is eager-loaded
  field :name, preload: :user do |review, _options|
    review.user&.name
  end

  # explicit author_name. Frontend modal
  # uses `review.author_name` from the row hash; ReviewBlueprint output
  # had only :name. Expose both for stability across the API.
  field :author_name, preload: :user do |review, _options|
    review.user&.name
  end

  # author_email is gated. Default
  # response omits it (a public-comment endpoint exposing every
  # commenter's email enables scraping during open comment windows).
  # Admin-tier surfaces (admin actions disclosure, disposition export)
  # opt in via `render_as_json(review, include_email: true)`. Mirrors
  # the disposition-export include_email pattern in
  # app/lib/disposition_matrix_export.rb.
  field :author_email,
        preload: :user,
        if: ->(_field, _review, options) { options && options[:include_email] } do |review, _options|
    review.user&.email
  end

  # display-layer attribution
  # for triager / adjudicator / commenter. See app/blueprints/
  # imported_attribution_fields.rb for the macro implementation
  # (top-level, NOT under concerns/ — only app/models/concerns and
  # app/controllers/concerns are Rails-special skip-namespace autoload
  # paths; placing the helper under app/blueprints/concerns would force
  # a Concerns:: prefix and break Zeitwerk constant resolution). The
  # three declarations below replace six hand-written `field` blocks.
  extend ImportedAttributionFields

  attribution_fields :triager,     via: :triage_set_by
  attribution_fields :adjudicator, via: :adjudicated_by
  attribution_fields :commenter,   via: :user

  field :commenter_email,
        preload: :user,
        if: ->(_field, _review, options) { options && options[:include_email] } do |review, _options|
    review.user&.email
  end

  # Controllers pass `reactions_summary: Reaction.summary(ids, current_user.id)`
  # via render_as_json options. Falls back to zeros + nil mine when the
  # option isn't supplied so older callers don't break.
  # Reads a summary the caller passes in; reaches nothing.
  field :reactions do |review, options|
    summary = options[:reactions_summary] || {}
    summary[review.id] || { up: 0, down: 0, mine: nil }
  end
end
