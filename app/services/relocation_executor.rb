# frozen_string_literal: true

# Lands an accepted relocation proposal: ONE transaction that creates
# the target requirement in the destination component (content moves
# with the requirement, lineage preserved), tombstones the source row,
# and stamps the record executed with the accepting actor — atomically,
# or not at all. Acceptance and landing are one action: there is no
# accepted-but-unlanded state. Dry-run previews the identical move with
# zero writes.
#
# Recount note: SRG-kind requirement counts are live scoped queries, so
# the tombstone corrects every count by construction — reset_counters
# (:rules) must never run here (it counts class Rule and would zero an
# SRG component's counter).
class RelocationExecutor
  class ExecutionError < StandardError; end

  Result = Struct.new(:relocation, :target_rule, keyword_init: true)

  def initialize(relocation, target_component:, accepted_by: nil)
    @relocation = relocation
    @target_component = target_component
    @accepted_by = accepted_by
  end

  # The zero-write preview: everything execute! would do, or the reasons
  # it cannot run.
  def dry_run
    source = @relocation.source_rule
    {
      valid: validation_errors.empty?,
      errors: validation_errors,
      source_displayed_name: "#{source.component.prefix}-#{source.rule_id}",
      target_component_id: @target_component&.id,
      target_component_name: @target_component&.name,
      would_create: {
        title: source.title,
        status: source.status,
        rule_id: @target_component && landed_rule_id,
        derived_from_srg_rule_id: source.derived_from_srg_rule_id
      },
      would_tombstone_source: true
    }
  end

  def execute!
    # A missing actor is a caller bug, not a domain state — landing is
    # always an acceptance by someone.
    raise ArgumentError, 'an accepting actor is required to land a proposal' if @accepted_by.nil?

    errors = validation_errors
    raise ExecutionError, errors.join('; ') if errors.any?

    source = @relocation.source_rule
    ApplicationRecord.transaction do
      target = build_target_row(source)
      target.save!
      # Tombstone before stamping: the one-directional invariant
      # (executed ⇒ source tombstoned) validates at the stamp.
      source.update!(deleted_at: Time.current)
      @relocation.update!(target_rule_id: target.id, executed_at: Time.current,
                          accepted_by: @accepted_by, accepted_at: Time.current)
      Result.new(relocation: @relocation, target_rule: target)
    end
  end

  # The ONE adjudication-eligibility oracle: every reason this proposal
  # cannot be adjudicated against this destination. Accept consults it
  # before landing; decline consults it before terminating — an author of
  # an ineligible component may do neither.
  def validation_errors
    @validation_errors ||= begin
      errors = []
      errors << 'proposal is no longer open' unless @relocation.proposed?
      errors << 'target component is required' if @target_component.nil?
      if @target_component
        errors << 'target component must be an SRG component' unless @target_component.document_type == 'srg'
        errors << 'target component is released' if @target_component.released
        errors << 'target component is the source component' if @relocation.source_rule.component_id == @target_component.id
        errors.concat(source_srg_coverage_errors)
      end
      errors
    end
  end

  private

  def build_target_row(source)
    row = source.dup_with_nested_records
    row.component_id = @target_component.id
    # The moved requirement takes the NEXT number in the target's own
    # sequence — a working number is a local ordinal, never identity
    # (final identifiers mint at release from lineage). Keeping the
    # source number would collide with the unique per-component index.
    row.rule_id = landed_rule_id
    # The moved requirement keeps its core lineage and its authored state.
    row.deleted_at = nil
    row.locked = false
    row.locked_fields = {}
    row.review_requestor_id = nil
    row
  end

  def landed_rule_id
    format('%06d', @target_component.largest_rule_id + 1)
  end

  # The parent-set invariant: every requirement's lineage belongs to a
  # declared source SRG of its component (same SRG, any release). A move
  # into a component that has not declared the source's core SRG would
  # violate it — the author adds that SRG as a source first
  # (add-parent-later), then the move can land.
  def source_srg_coverage_errors
    derived_from = @relocation.source_rule.derived_from
    return [] if derived_from.nil?

    source_srg_id = derived_from.security_requirements_guide.srg_id
    return [] if @target_component.source_srgs.any? { |srg| srg.srg_id == source_srg_id }

    ["target component does not declare #{source_srg_id} as a source SRG — add it first"]
  end
end
