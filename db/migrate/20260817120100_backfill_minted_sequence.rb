# frozen_string_literal: true

# Backfills minted_sequence for rows already minted under the previous
# (string-shape) minter, so the new column-based recognition carries their
# published identifiers forward instead of renumbering them on the first
# re-release after deploy.
#
# Recognition here is PER-ROW and exact — deliberately NOT the legacy
# MINTED_WITH_LINEAGE regex, which false-matches a raw 5-segment SRG core.
# A lineage-minted id is its own derived_from.version followed by
# "-<TOKEN>-<6 digits>"; a net-new minted id is "<TOKEN>-<6 digits>". We
# anchor on the row's own core (self-join on derived_from_srg_rule_id) so a
# raw core can never be mistaken for a minted id, and we do not depend on
# the component's current abbreviation (it may have changed since minting).
# Scoped to authored rows (component_id present); catalog SRG rules are
# excluded. The trailing 6 digits are the stamped sequence.
class BackfillMintedSequence < ActiveRecord::Migration[8.0]
  def up
    # safety_assured: strong_migrations cannot introspect raw execute. These
    # are bounded UPDATEs over authored rows only (component_id NOT NULL — a
    # small subset of base_rules, indexed by component_id) that set a
    # nullable column; no table rewrite, no long-held lock on the catalog.
    safety_assured do
      # Lineage-minted: version == derived_from.version + "-<TOKEN>-<seq>"
      execute(<<~SQL.squish)
        UPDATE base_rules r
        SET minted_sequence = (regexp_match(r.version, '-([0-9]{6})$'))[1]::int
        FROM base_rules d
        WHERE r.type = 'SrgRule'
          AND r.component_id IS NOT NULL
          AND r.minted_sequence IS NULL
          AND r.version IS NOT NULL
          AND r.derived_from_srg_rule_id = d.id
          AND d.version IS NOT NULL
          AND left(r.version, length(d.version) + 1) = d.version || '-'
          AND substr(r.version, length(d.version) + 2) ~ '^[A-Z]+-[0-9]{6}$'
      SQL

      # Net-new minted: version == "<TOKEN>-<seq>" (no lineage core).
      execute(<<~SQL.squish)
        UPDATE base_rules r
        SET minted_sequence = (regexp_match(r.version, '-([0-9]{6})$'))[1]::int
        WHERE r.type = 'SrgRule'
          AND r.component_id IS NOT NULL
          AND r.minted_sequence IS NULL
          AND r.derived_from_srg_rule_id IS NULL
          AND r.version ~ '^[A-Z]+-[0-9]{6}$'
          AND r.version !~ '^SRG-'
      SQL
    end
  end

  def down
    # No-op: minted_sequence is derived from the published identifier and is
    # dropped with the column if the schema is rolled back.
  end
end
