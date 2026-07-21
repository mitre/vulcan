# frozen_string_literal: true

# A relocation is a RECORD, never a status. A proposed row (no
# adjudication stamps) is the move marker on an authored SRG requirement:
# it renders as the row badge, feeds the per-family backlog of open
# proposals, and un-marking (source-side withdrawal) simply destroys it.
# The RECEIVING side adjudicates: acceptance lands the move (executed,
# stamped with the accepting actor in the same transaction) and decline
# is a RETAINED terminal state with required rationale — communication
# back to the source author, never a destroy. Adjudicated records
# (declined or executed) are immutable to users; the system-side cascade
# from a hard-destroyed source rule removes history with the source,
# exactly like every other dependent record.
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
  belongs_to :accepted_by, class_name: 'User', optional: true
  belongs_to :declined_by, class_name: 'User', optional: true
  has_one :component, through: :source_rule

  vulcan_audited associated_with: :component

  scope :proposed, -> { where(executed_at: nil, declined_at: nil) }
  scope :declined, -> { where.not(declined_at: nil) }
  scope :executed, -> { where.not(executed_at: nil) }
  # Everything the backlog serves: open proposals plus retained declines
  # (the source author's visibility into why); executed history stays out.
  scope :unexecuted, -> { where(executed_at: nil) }
  # The per-family backlog: open proposals destined for a technology
  # token, across all source components.
  scope :backlog_for, ->(token) { proposed.where(target_technology_token: token) }
  # The orphan sweep: executed history whose landed target was later
  # destroyed (target FK nullified with an audit note).
  scope :executed_orphaned, -> { executed.where(target_rule_id: nil) }

  validates :target_technology_token, presence: true
  # One open proposal per source (backed by the partial unique index);
  # declined and executed history is unbounded.
  validates :source_rule_id,
            uniqueness: { conditions: -> { where(executed_at: nil, declined_at: nil) },
                          message: :open_proposal_exists },
            if: :proposed?
  # Decline is communication back across the boundary — the rationale is
  # the message, so it is required, not optional.
  validates :adjudication_rationale, presence: true, if: :declined?
  validate :source_must_be_an_authored_srg_requirement
  validate :declined_and_executed_are_exclusive
  validate :adjudicated_records_are_immutable, on: :update
  # The one-directional invariant: executed implies the source row is
  # tombstoned — enforced here AND by the executor transaction.
  validate :executed_requires_tombstoned_source, if: -> { executed_at.present? }

  def proposed?
    executed_at.nil? && declined_at.nil?
  end

  def declined?
    declined_at.present?
  end

  private

  # Relocation exists on the source side of SRG authoring only — never on
  # catalog rows and never on stig-kind components.
  def source_must_be_an_authored_srg_requirement
    return if source_rule.nil? # belongs_to presence reports separately
    return if source_rule.component&.document_type == 'srg'

    errors.add(:source_rule, 'must be an authored requirement of an SRG component')
  end

  # Decline and acceptance are the two mutually exclusive outcomes of
  # adjudication — one record never carries both.
  def declined_and_executed_are_exclusive
    return unless declined_at.present? && executed_at.present?

    errors.add(:base, 'a relocation cannot be both declined and executed')
  end

  # Proposed -> executed (the executor's transaction) and proposed ->
  # declined (receiver adjudication) are the only permitted transitions;
  # an adjudicated record never changes again — except the system-side
  # target release (target_rule_id -> nil with an audit note) when the
  # landed row is destroyed, the same system-not-user pattern as the
  # source-side cascade.
  def adjudicated_records_are_immutable
    return if executed_at_was.nil? && declined_at_was.nil?
    return if changes.keys == ['target_rule_id'] && target_rule_id.nil?

    errors.add(:base, "#{executed_at_was.nil? ? 'declined' : 'executed'} relocation records are immutable")
  end

  def executed_requires_tombstoned_source
    return if source_rule.nil?
    return if source_rule.deleted_at.present?

    errors.add(:executed_at, 'requires the source requirement to be tombstoned first')
  end
end
