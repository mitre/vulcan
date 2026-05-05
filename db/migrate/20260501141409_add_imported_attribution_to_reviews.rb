# frozen_string_literal: true

# PR-717 review remediation .8 — preserve original attribution per-review
# on cross-instance restore.
#
# When a json_archive is imported and a triage_set_by_email or
# adjudicated_by_email in the archive can't be resolved to a User on the
# target instance, the FK is left nil and these columns carry forward the
# original email + name from the archive. Display + export layers fall
# back to these when the FK is nil.
#
# Researched alternatives:
#   - GitLab's "placeholder user" pattern creates separate User records of
#     a Placeholder type plus an Import::SourceUser join model. Overkill
#     for Vulcan's one-shot backup/restore use case.
#   - Discourse's external_id is a different problem (continuous SSO).
# 4 nullable string columns is the per-record version of the same idea
# without the separate-user-record + join-table overhead.
class AddImportedAttributionToReviews < ActiveRecord::Migration[8.0]
  def change
    change_table :reviews, bulk: true do |t|
      t.string :triage_set_by_imported_email
      t.string :triage_set_by_imported_name
      t.string :adjudicated_by_imported_email
      t.string :adjudicated_by_imported_name
    end
  end
end
