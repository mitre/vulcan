# frozen_string_literal: true

# The ONE requirement-import machinery for a component's declared source
# SRGs — full union across all parents, selective import behind a
# requirement filter, and the add-parent-later path are the same engine.
#
# Kind routing lives here and nowhere else:
# - stig components import class-Rule rows per parent through the existing
#   single-SRG import (Component#from_mapping), numbering sequentially
#   across parents.
# - srg components generate AUTHORED SrgRules: content is copied from the
#   persisted catalog rows, each generated row sets component_id and
#   derived_from_srg_rule_id and leaves security_requirements_guide_id
#   NULL (the authored/catalog XOR). SrgRule.from_mapping and the amoeba
#   become_rule path both emit catalog-shaped or wrong-typed rows and are
#   never used here.
class RequirementImportService
  def initialize(component)
    @component = component
  end

  # Import from ALL declared parents. Without selections this is the full
  # union (default): every requirement of every parent. With selections —
  # { security_requirements_guide_id => [version, ...] } — each parent
  # contributes only its selected requirements, and a parent absent from
  # the map contributes none. Atomic: any parent failing rolls back all.
  def import_all!(selections: nil)
    @component.transaction do
      parents_primary_first.each do |srg|
        versions = selections ? Array(selections[srg.id]) : nil
        next if versions&.empty?

        import_parent!(srg, versions: versions)
      end
    end
  end

  # Import one declared parent's requirements. versions: nil imports the
  # parent's full requirement set; a version list imports only those
  # requirements (selective mode — the same generator behind a filter).
  def import_parent!(srg, versions: nil)
    case @component.document_type
    when 'srg'
      generate_authored_requirements!(srg, versions)
    when 'stig'
      import_stig_rules!(srg, versions)
    else
      raise ArgumentError, "no requirement import for document_type #{@component.document_type.inspect}"
    end
  end

  private

  # Primary parent first, remaining parents ordered by SRG id — a
  # deterministic total order so stig-kind sequential rule numbering is
  # stable across runs.
  def parents_primary_first
    @component.source_srgs.to_a
              .sort_by { |srg| [srg.id == @component.security_requirements_guide_id ? 0 : 1, srg.id] }
  end

  # The authored generator: catalog row content -> authored SrgRule rows,
  # bulk-inserted with nested records and the initial creation audit
  # (activerecord-import bypasses callbacks, matching the Rule path).
  def generate_authored_requirements!(srg, versions)
    rows = catalog_rows(srg, versions).map { |catalog_row| build_authored_row(catalog_row) }
    failed = SrgRule.import(rows, all_or_none: true, recursive: true).failed_instances
    return if failed.blank?

    @component.errors.add(:base, 'Some requirements failed to import from the source SRG.')
    raise ActiveRecord::RecordInvalid, @component
  end

  def catalog_rows(srg, versions)
    scope = srg.srg_rules
    versions.nil? ? scope : scope.where(version: versions)
  end

  def build_authored_row(catalog_row)
    row = catalog_row.dup
    row.component_id = @component.id
    row.derived_from_srg_rule_id = catalog_row.id
    row.security_requirements_guide_id = nil
    # Authored rows start at the beginning of the SRG lifecycle regardless
    # of any catalog status.
    row.status = RuleConstants::STATUS_NYD
    copy_nested_records(catalog_row, row)
    row.audits.build(Audited.audit_class.create_initial_rule_audit_from_mapping(@component.id))
    row
  end

  def copy_nested_records(catalog_row, row)
    %i[rule_descriptions disa_rule_descriptions checks references].each do |assoc|
      row.public_send(:"#{assoc}=", catalog_row.public_send(assoc).map(&:dup))
    end
  end

  # Today's single-SRG import, run per parent: rule numbering continues
  # from the component's current highest so a union across parents is one
  # sequence. from_mapping collects its own failures onto the component.
  def import_stig_rules!(srg, versions)
    return if @component.from_mapping(srg, versions, @component.largest_rule_id)

    raise ActiveRecord::RecordInvalid, @component
  end
end
