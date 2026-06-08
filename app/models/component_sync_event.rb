# frozen_string_literal: true

# Per-merge audit row. One ComponentSyncEvent is created at the start of
# every component sync (inbound or outbound), wired to the snapshot path,
# archive hash, and downstream merge_operations + merge_quarantine rows.
# parent_sync_id chains successive syncs.
class ComponentSyncEvent < ApplicationRecord
  STATUSES   = %w[pending analyzed applied failed undone].freeze
  DIRECTIONS = %w[inbound outbound].freeze

  belongs_to :component
  has_many :merge_operations, dependent: :destroy
  has_many :merge_quarantine_records, dependent: :destroy

  # sync_id is the natural key — parent_sync_id and external references use
  # it (not the DB pk), so duplicates would corrupt the chain. Index in
  # CreateComponentSyncEvents enforces uniqueness at the DB level too.
  validates :sync_id, presence: true, uniqueness: true
  validates :source, :direction, presence: true
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :status,    inclusion: { in: STATUSES }

  # At most one pending sync per component. Backed by a partial unique index
  # (index_component_sync_events_on_pending_component). Validation gives a
  # readable message; the index is the authoritative race-safe constraint.
  # rubocop:disable Rails/I18nLocaleTexts -- consistent with neighbor validators
  validates :component_id,
            uniqueness: { conditions: -> { where(status: 'pending') },
                          message: 'already has a pending sync' },
            if: -> { status == 'pending' }

  # Replay protection: same archive_hash can't reach status='applied'
  # on the same component twice. Backed by partial unique index
  # (index_component_sync_events_on_applied_archive_hash). Only enforced
  # when archive_hash is present AND status='applied' (pending/failed
  # rows for the same hash are fine — those are in-flight or aborted).
  validates :archive_hash,
            uniqueness: { scope: :component_id,
                          conditions: -> { where(status: 'applied').where.not(archive_hash: nil) },
                          message: 'this archive has already been applied to this component' },
            if: -> { archive_hash.present? && status == 'applied' }
  # rubocop:enable Rails/I18nLocaleTexts
end
