# frozen_string_literal: true

# Raw archive records that failed merge validation. Operators inspect these
# in the merge UI, fix the underlying issue (re-parent a cross-rule reply,
# resolve a missing FK target, etc.), and retry via `rake sync:retry_quarantined`.
# Stores the full original_archive_data so retries can replay the record
# verbatim against the corrected state.
class MergeQuarantineRecord < ApplicationRecord
  # Table name diverges from the model: 'merge_quarantine' is a collective
  # noun (the quarantine area), while each row is a *quarantined record*.
  self.table_name = 'merge_quarantine'

  belongs_to :component_sync_event

  validates :entity_type, :entity_key, :quarantine_reason, :original_archive_data, presence: true
end
