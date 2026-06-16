# frozen_string_literal: true

# Durable diagnostic trail on a failed merge. When the apply
# txn rolls back (PreconditionError, SerializationFailure, StandardError),
# the Applier captures exception class+message + structured_errors +
# warnings into this column so operators can SELECT and triage 5 minutes
# after the failure without re-running the merge.
class AddFailureDiagnosticsToComponentSyncEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :component_sync_events, :failure_diagnostics_json, :jsonb
  end
end
