# frozen_string_literal: true

# A relocation is a RECORD, never a status. A pending row (executed_at
# NULL) is the move marker on an authored SRG requirement: it renders as
# the row badge, feeds the per-family backlog, and un-marking simply
# destroys it. An executed row is the immutable lifecycle fact that the
# requirement moved out — users can neither edit nor delete it (the
# controller refuses; the update validation freezes it), while the
# system-side cascade from a hard-destroyed source rule removes history
# with the source, exactly like every other dependent record.
class RequirementRelocation < ApplicationRecord
  include VulcanAuditable

  # The source is always an authored SrgRule; unscope the soft-delete
  # default scope so executed records can still reach their tombstoned
  # source row.
  belongs_to :source_rule, -> { unscope(where: :deleted_at) },
             class_name: 'SrgRule', inverse_of: :requirement_relocations
  belongs_to :target_rule, -> { unscope(where: :deleted_at) },
             class_name: 'SrgRule', optional: true, inverse_of: false
  belongs_to :requested_by, class_name: 'User', optional: true
  has_one :component, through: :source_rule

  vulcan_audited associated_with: :component

  scope :pending, -> { where(executed_at: nil) }
  scope :executed, -> { where.not(executed_at: nil) }
  # The per-family backlog: pending markers destined for a technology
  # token, across all source components.
  scope :backlog_for, ->(token) { pending.where(target_technology_token: token) }
  # The orphan sweep: executed history whose landed target was later
  # destroyed (target FK nullified with an audit note).
  scope :executed_orphaned, -> { executed.where(target_rule_id: nil) }

  validates :target_technology_token, presence: true
  # One pending marker per source (backed by the partial unique index);
  # executed history is unbounded.
  validates :source_rule_id,
            uniqueness: { conditions: -> { where(executed_at: nil) },
                          message: :pending_exists },
            if: :pending?
  validate :source_must_be_an_authored_srg_requirement
  validate :executed_records_are_immutable, on: :update
  # The one-directional invariant: executed implies the source row is
  # tombstoned — enforced here AND by the executor transaction.
  validate :executed_requires_tombstoned_source, if: -> { executed_at.present? }

  def pending?
    executed_at.nil?
  end

  private

  # Relocation exists on the source side of SRG authoring only — never on
  # catalog rows and never on stig-kind components.
  def source_must_be_an_authored_srg_requirement
    return if source_rule.nil? # belongs_to presence reports separately
    return if source_rule.component&.document_type == 'srg'

    errors.add(:source_rule, 'must be an authored requirement of an SRG component')
  end

  # Pending -> executed is the one permitted transition (the executor's
  # transaction); a record that was already executed never changes again —
  # except the system-side target release (target_rule_id -> nil with an
  # audit note) when the landed row is destroyed, the same
  # system-not-user pattern as the source-side cascade.
  def executed_records_are_immutable
    return if executed_at_was.nil?
    return if changes.keys == ['target_rule_id'] && target_rule_id.nil?

    errors.add(:base, 'executed relocation records are immutable')
  end

  def executed_requires_tombstoned_source
    return if source_rule.nil?
    return if source_rule.deleted_at.present?

    errors.add(:executed_at, 'requires the source requirement to be tombstoned first')
  end
end
