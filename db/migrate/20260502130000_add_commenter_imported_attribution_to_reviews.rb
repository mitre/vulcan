# frozen_string_literal: true

# PR-717 review remediation .j4a step A1 — preserve original commenter
# attribution when User#destroy nullifies reviews.user_id (post-A3
# FK on_delete: :nullify) or when a json_archive import carries a
# commenter email/name that doesn't resolve to a User on the target
# instance.
#
# Mirrors the `triage_set_by_imported_email/_name` +
# `adjudicated_by_imported_email/_name` columns added in
# 20260501141409_add_imported_attribution_to_reviews (PR-717 .8).
# Display + export layers fall back to these when reviews.user_id is nil.
class AddCommenterImportedAttributionToReviews < ActiveRecord::Migration[8.0]
  def change
    change_table :reviews, bulk: true do |t|
      t.string :commenter_imported_email
      t.string :commenter_imported_name
    end
  end
end
