# frozen_string_literal: true

# Attaches a released SRG component to the catalog the registry way:
# mint identifiers, generate the published XCCDF, create the catalog
# SecurityRequirementsGuide row with columns derived FROM that artifact
# (the stored document is authoritative; the columns are its projection —
# the header consistency validation enforces the match), then populate
# its rules through the release copy. The released entry is shaped
# exactly like an uploaded SRG, so basing, is-latest, and seeds work
# unchanged.
#
# Also builds the release changelog: structured removals data from
# executed relocation records, plus a plain-text rendering. Storage and
# serving belong to the release endpoint.
class ReleaseAttachmentService
  class ReleaseBlockedError < StandardError; end

  def initialize(component)
    @component = component
  end

  # Every reason the attachment cannot run, without raising. The version
  # pair is never defaulted — a component without explicit version and
  # release integers has not decided what it is releasing.
  def validation_errors
    @validation_errors ||= begin
      errors = ReleaseCopyService.new(@component, catalog_srg: nil).component_validation_errors.dup
      missing_version = @component.version.blank? || @component.release.blank?
      errors << 'component version and release must be set before attaching to the catalog' if missing_version
      errors << 'component has no abbreviation to mint with' if @component.technology_token.blank?
      errors
    end
  end

  # One transaction: mint -> generate -> catalog row from the artifact ->
  # release copy. A failure anywhere leaves no catalog row, no copies,
  # and no stamps.
  def attach!
    errors = validation_errors
    raise ReleaseBlockedError, errors.join('; ') if errors.any?

    ApplicationRecord.transaction do
      rows = ReleaseCopyService.new(@component, catalog_srg: nil).publishable_rows.to_a
      # Minted identifiers must exist before generation — the published
      # document carries them in its Rule version elements.
      ReleaseIdentifierMinter.new(@component).mint!(rows)
      xml = Export::Base.new(exportable: @component, mode: :published_srg, format: :xccdf).call.data
      catalog = create_catalog_row(xml)
      ReleaseCopyService.new(@component, catalog_srg: catalog).copy!
      catalog
    end
  end

  # Structured changelog content: removals are the component's executed
  # relocation records — the requirement left this document for another
  # SRG's next release.
  def changelog_data
    {
      version: SecurityRequirementsGuide.version_string(@component.version, @component.release),
      removals: executed_relocations.map do |relocation|
        source = relocation.source_rule
        { identifier: source.version.presence || "#{@component.prefix}-#{source.rule_id}",
          destination_abbreviation: relocation.target_technology_token,
          executed_on: relocation.executed_at.to_date }
      end
    }
  end

  def changelog_text
    data = changelog_data
    lines = ["#{@component.name} #{data[:version]} — Release Changelog", '']
    if data[:removals].empty?
      lines << 'No requirements were removed in this release.'
    else
      lines << 'Removals:'
      data[:removals].each do |removal|
        lines << "- #{removal[:identifier]} relocated to #{removal[:destination_abbreviation]} " \
                 "(#{removal[:executed_on]})"
      end
    end
    lines.join("\n")
  end

  private

  def create_catalog_row(xml)
    fields = SecurityRequirementsGuide.header_fields(xml)
    SecurityRequirementsGuide.create!(
      srg_id: fields[:srg_id], title: fields[:title], version: fields[:version],
      release_date: fields[:release_date],
      name: SecurityRequirementsGuide.display_name(fields[:srg_id], fields[:version]),
      xml: xml, skip_rule_import: true
    )
  end

  # Executed relocations whose source row lives on this component. The
  # sources are tombstoned by definition (executed implies tombstoned),
  # so the scan is unscoped — the same tombstone-inclusive read the
  # identifier minter uses.
  def executed_relocations
    RequirementRelocation.executed
                         .where(source_rule_id: SrgRule.unscoped.where(component_id: @component.id).select(:id))
                         .order(:executed_at)
  end
end
