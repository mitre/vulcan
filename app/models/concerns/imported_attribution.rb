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
# Display fallback (matches the original .8 / .j4a methods exactly):
#   public_send(via)&.name.presence ||
#     public_send("#{column_prefix}_imported_name").presence ||
#     public_send("#{column_prefix}_imported_email").presence
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

      define_method("#{role}_display_name") do
        public_send(via)&.name.presence ||
          public_send(imported_name).presence ||
          public_send(imported_email).presence
      end

      define_method("#{role}_imported?") do
        public_send(via_id).nil? &&
          (public_send(imported_name).present? || public_send(imported_email).present?)
      end
    end
  end
end
