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
      errors = component_validation_errors.dup
      errors << 'a catalog SRG row is required' if @catalog_srg.nil?
      errors
    end
  end

  # The component-side release blocks, independent of the catalog row —
  # the release attachment consults these before the catalog row exists.
  def component_validation_errors
    @component_validation_errors ||= begin
      errors = []
      errors << 'component must be an SRG component' unless @component.document_type == 'srg'
      undetermined = live_rows.where(status: RuleConstants::STATUS_NYD).count
      if undetermined.positive?
        errors << "release is blocked: #{undetermined} live requirement(s) still " \
                  'Not Yet Determined — every requirement must be decided'
      end
      errors
    end
  end

  # The release population: live, decided rows in canonical order — the
  # ONE selection shared by identifier minting, the published export, and
  # the catalog copy.
  def publishable_rows
    live_rows.where.not(status: RuleConstants::STATUS_NOT_APPLICABLE).canonical_order
  end

  # Copies all live, non-NA rows atomically and returns the catalog rows.
  def copy!
    errors = validation_errors
    raise ReleaseBlockedError, errors.join('; ') if errors.any?

    ApplicationRecord.transaction do
      rows = publishable_rows.to_a
      # Final derived identifiers mint here — in the release transaction,
      # stamped on the authored rows so the catalog copy carries them and
      # next-release duplicates keep them stable. Already-minted rows are
      # left byte-identical, so a caller that minted earlier (the release
      # attachment mints before generating the XCCDF) stays correct.
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
    # Uploaded shape: a catalog row's rule_id is its document's Rule
    # element id — the join key the basing import matches against the
    # parsed XCCDF. The working ordinal stays on the authored row.
    copy.rule_id = PublishedIdentifiers.rule(@component.prefix, row.rule_id)
    # Uploaded shape: the applicability decision stays on the component.
    copy.status = RuleConstants::STATUS_NYD
    copy.status_justification = nil
    copy.reset_authored_copy_state
    raise ReleaseBlockedError, "release copy produced a #{copy.class}, expected SrgRule" unless copy.instance_of?(SrgRule)

    copy.save!
    copy
  end
end
