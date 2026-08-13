# frozen_string_literal: true

# The SRG rebase: reconcile an in-memory component duplicate's authored
# rows against a new core SRG release, then persist. Matched derived rows
# (stable core version ids) re-link and refresh inherited fields;
# vanished-core rows are KEPT with their old lineage and reported — an NA
# justification is authored judgment, never silently destroyed; arrived
# core requirements are generated as NYD authored rows through the one
# import machinery; net-new rows (no lineage) carry untouched. The
# reconcile summary lands on Component#rebase_report and in a durable
# audit entry — never silent.
class SrgRebaseService
  # Non-authored fields a derived requirement inherits from its core
  # catalog row — refreshed on rebase; authored content (title, fixtext,
  # descriptions, checks, status, justifications) is never touched.
  INHERITED_FIELDS = %i[rule_severity rule_weight ident ident_system
                        fixtext_fixref fix_id].freeze

  def initialize(copied_component, new_srg)
    @copied_component = copied_component
    @new_srg = new_srg
  end

  def call
    new_rows_by_version = @new_srg.srg_rules.canonical_order.index_by(&:version)
    report = { relinked: 0, content_changed: 0, vanished: 0, arrived: 0 }
    covered_versions = reconcile_carried_rows(new_rows_by_version, report)

    return @copied_component unless @copied_component.save

    import_arrived_rows(new_rows_by_version.keys - covered_versions, report)
    record_report(report)
    @copied_component
  end

  private

  def reconcile_carried_rows(new_rows_by_version, report)
    old_lineage = SrgRule.unscoped
                         .where(id: @copied_component.authored_srg_rules.filter_map(&:derived_from_srg_rule_id))
                         .index_by(&:id)
    covered_versions = []

    @copied_component.authored_srg_rules.each do |row|
      old_row = old_lineage[row.derived_from_srg_rule_id]
      next if old_row.nil? # net-new authored row — untouched

      new_row = new_rows_by_version[old_row.version]
      if new_row.nil?
        report[:vanished] += 1
        next
      end

      covered_versions << new_row.version
      relink(row, old_row, new_row, report)
    end

    covered_versions
  end

  def relink(row, old_row, new_row, report)
    row.derived_from_srg_rule_id = new_row.id
    INHERITED_FIELDS.each { |field| row[field] = new_row[field] }
    report[:content_changed] += 1 if content_changed?(old_row, new_row)
    report[:relinked] += 1
  end

  def import_arrived_rows(arrived_versions, report)
    return if arrived_versions.empty?

    RequirementImportService.new(@copied_component).import_parent!(@new_srg, versions: arrived_versions)
    report[:arrived] = arrived_versions.size
  end

  def record_report(report)
    @copied_component.audits.create(
      action: 'update', audited_changes: {},
      comment: "Core SRG rebase to #{@new_srg.name}: #{report[:relinked]} re-linked " \
               "(#{report[:content_changed]} with changed core content), " \
               "#{report[:vanished]} kept without a core counterpart, " \
               "#{report[:arrived]} new core requirements added as Not Yet Determined."
    )
    @copied_component.reload
    @copied_component.rebase_report = report
  end

  # The fields an author's determination is made against — a change in any
  # of them flags the row for re-review in the rebase report.
  def content_changed?(old_row, new_row)
    return true if %i[title fixtext].any? { |field| old_row[field] != new_row[field] }

    old_row.disa_rule_descriptions.first&.vuln_discussion !=
      new_row.disa_rule_descriptions.first&.vuln_discussion
  end
end
