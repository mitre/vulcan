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
end
