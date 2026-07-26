# frozen_string_literal: true

# Mints final derived identifiers at release, following the published
# DISA pattern (SRG-APP-000014-CTR-000035): the core-half comes from each
# requirement's OWN derived_from lineage — never the component's primary
# parent — joined to the component's abbreviation and a 6-digit local
# sequence. The sequence counter is DOCUMENT-WIDE: one counter across all
# core namespaces, because the sequence identifies the derived
# requirement while the core-half identifies the mapping (published DISA
# documents repeat sequences across mappings; uniqueness lives in the
# full identifier). A net-new requirement without lineage mints
# ABBREVIATION-SEQUENCE from the same counter — the STIG
# added-requirement pattern.
#
# Minted identifiers are stamped on the AUTHORED row (audited, inside the
# release transaction) so next-release duplicates carry them forward
# byte-identical — a published identifier is never re-minted or
# renumbered. Sequence numbers are never reused: the high-water scan
# covers every authored row of the component, including tombstoned and
# Not Applicable rows.
#
# Identifier shape, not the component's current abbreviation, decides
# whether a row is already minted — so a prefix change between releases
# can never trigger a renumber of previously published identifiers.
class ReleaseIdentifierMinter
  class MintError < StandardError; end

  # Core requirement id (SRG-OS-000801) + abbreviation + sequence.
  MINTED_WITH_LINEAGE = /\ASRG-[A-Z]+-\d+-[A-Z]+-\d+\z/
  # Net-new shape: abbreviation + sequence, no core-half.
  MINTED_NET_NEW = /\A(?!SRG-)[A-Z]+-\d+\z/

  def initialize(component)
    @component = component
  end

  # Stamps minted identifiers on the given authored rows (the release
  # population — live, decided rows) inside the caller's transaction.
  # Rows already carrying a minted identifier are left byte-identical.
  def mint!(rows)
    token = @component.technology_token
    raise MintError, 'component has no abbreviation to mint with' if token.blank?

    sequence = highest_minted_sequence
    BaseRule.canonical_sort(rows.reject { |row| minted?(row.version) }).each do |row|
      sequence += 1
      row.update!(version: minted_identifier(row, token, sequence),
                  audit_comment: 'Identifier minted at release')
    end
    rows
  end

  private

  def minted_identifier(row, token, sequence)
    core_half = row.derived_from&.version
    suffix = "#{token}-#{format('%06d', sequence)}"
    core_half.present? ? "#{core_half}-#{suffix}" : suffix
  end

  def minted?(version)
    version.present? && (version.match?(MINTED_WITH_LINEAGE) || version.match?(MINTED_NET_NEW))
  end

  # The document-wide high-water mark. Scans EVERY authored row of the
  # component — tombstoned and Not Applicable included — so a retired
  # sequence number is never reissued.
  def highest_minted_sequence
    SrgRule.unscoped.where(component_id: @component.id).pluck(:version)
           .select { |version| minted?(version) }
           .map { |version| version[/-(\d+)\z/, 1].to_i }
           .max || 0
  end
end
