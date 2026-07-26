# frozen_string_literal: true

# Copies an SRG component's live, non-Not-Applicable authored SrgRules
# into fresh CATALOG SrgRule rows on the released catalog entry — the
# component's requirements become the released SRG's requirements, shaped
# identically to an uploaded one. Deliberately NOT SrgRule's amoeba block:
# that block retypes to Rule (the basing/import path) and would emit a
# wrong-typed row the type-scoped XOR constraint cannot catch. The copy
# dups AS SrgRule via the shared nested-record mechanic and asserts the
# resulting type.
#
# Catalog copies reset status to Not Yet Determined: inclusion in the
# catalog IS the record of the Applicable decision, and applicability on
# a catalog row is the downstream STIG author's decision-to-be. The
# component keeps every authored row — including Not Applicable rows and
# their required justifications — as the editable working record, with
# reviews and history staying on the component. Core lineage
# (derived_from) carries onto the catalog copy; identifier minting
# consumes it at release.
#
# The copy is blocked while any live row is still Not Yet Determined:
# every remaining requirement must be decided before release.
class ReleaseCopyService
  class ReleaseBlockedError < StandardError; end

  def initialize(component, catalog_srg:)
    @component = component
    @catalog_srg = catalog_srg
  end

  # Every reason the release copy cannot run, without raising — callers
  # (the release flow, its UI) consult this before attempting the copy.
  def validation_errors
    @validation_errors ||= begin
      errors = []
      errors << 'component must be an SRG component' unless @component.document_type == 'srg'
      errors << 'a catalog SRG row is required' if @catalog_srg.nil?
      undetermined = live_rows.where(status: RuleConstants::STATUS_NYD).count
      if undetermined.positive?
        errors << "release is blocked: #{undetermined} live requirement(s) still " \
                  'Not Yet Determined — every requirement must be decided'
      end
      errors
    end
  end

  # Copies all live, non-NA rows atomically and returns the catalog rows.
  def copy!
    errors = validation_errors
    raise ReleaseBlockedError, errors.join('; ') if errors.any?

    ApplicationRecord.transaction do
      rows = live_rows.where.not(status: RuleConstants::STATUS_NOT_APPLICABLE)
                      .canonical_order.to_a
      # Final derived identifiers mint here — in the release transaction,
      # stamped on the authored rows so the catalog copy carries them and
      # next-release duplicates keep them stable.
      ReleaseIdentifierMinter.new(@component).mint!(rows)
      rows.map { |row| copy_row(row) }
    end
  end

  private

  # The authored default scope already hides tombstones; the explicit
  # deleted_at guard keeps this selection correct even under unscoped
  # callers.
  def live_rows
    @component.authored_srg_rules.where(deleted_at: nil)
  end

  def copy_row(row)
    copy = row.dup_with_nested_records
    copy.component = nil
    copy.security_requirements_guide = @catalog_srg
    # Uploaded shape: the applicability decision stays on the component.
    copy.status = RuleConstants::STATUS_NYD
    copy.status_justification = nil
    copy.locked = false
    copy.locked_fields = {}
    copy.review_requestor_id = nil
    raise ReleaseBlockedError, "release copy produced a #{copy.class}, expected SrgRule" unless copy.instance_of?(SrgRule)

    copy.save!
    copy
  end
end
