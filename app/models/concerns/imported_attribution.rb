# frozen_string_literal: true

# Generates `<role>_display_name` and `<role>_imported?` instance methods
# on the including model. PR-717 review remediation: by mid-branch we had
# three role-prefixes on Review (triager / adjudicator / commenter) that
# all needed the same fallback chain — resolved User name → imported_name
# → imported_email → nil — and the same imported? predicate. Six
# hand-written method bodies became one `define_method` block here.
#
# Usage in the model:
#
#   include ImportedAttribution
#   imported_attribution :triager,    via: :triage_set_by
#   imported_attribution :adjudicator, via: :adjudicated_by
#   imported_attribution :commenter,  via: :user, column_prefix: :commenter
#
# Parameters:
#   role          — method-name prefix. The model exposes
#                   `<role>_display_name` and `<role>_imported?`.
#   via:          — the belongs_to association name. The macro reads
#                   `<via>` for the User and `<via>_id` for the FK
#                   nil-check.
#   column_prefix — the prefix on the `imported_email` / `imported_name`
#                   columns. Defaults to `via` (which matches the .8
#                   convention for triager + adjudicator). Commenter
#                   declares `column_prefix: :commenter` explicitly
#                   because its column-prefix doesn't match `user`.
#
# Display fallback:
#   public_send(via)&.name.presence ||
#     public_send("#{column_prefix}_imported_name").presence ||
#     "(imported #{role})" if email column is populated, else nil
#
# The email-column fallback is intentionally redacted to a role label
# rather than the raw email. Imported attribution columns are populated
# from JSON archives that may carry real user emails from the source
# instance; surfacing them in payloads readable by every project member
# (or, for released components, every logged-in user) creates a PII-
# scraping vector. Display still signals "this attribution came from an
# import" via the (imported X) label and the *_imported? predicate.
#
# Imported predicate:
#   public_send("#{via}_id").nil? &&
#     (public_send("#{column_prefix}_imported_name").present? ||
#      public_send("#{column_prefix}_imported_email").present?)
module ImportedAttribution
  extend ActiveSupport::Concern

  class_methods do
    def imported_attribution(role, via:, column_prefix: via)
      imported_email = "#{column_prefix}_imported_email"
      imported_name  = "#{column_prefix}_imported_name"
      via_id         = "#{via}_id"
      redacted_label = "(imported #{role})"

      define_method("#{role}_display_name") do
        public_send(via)&.name.presence ||
          public_send(imported_name).presence ||
          (redacted_label if public_send(imported_email).present?)
      end

      define_method("#{role}_imported?") do
        public_send(via_id).nil? &&
          (public_send(imported_name).present? || public_send(imported_email).present?)
      end
    end
  end
end
