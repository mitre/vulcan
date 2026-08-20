# frozen_string_literal: true

require 'rails_helper'

# Requirement: BaseRule exposes ONE canonical DISA display order — by `version`
# (STIG-ID / SRG-ID, zero-padded so lexical == canonical), then `rule_id`, then
# `id` as the unique tiebreaker (a deterministic TOTAL order). It is expressed
# two ways that MUST agree: `canonical_order` (SQL, for query paths) and
# `canonical_sort` (in-memory, for already-loaded serialization collections).
# `version` is nullable, so both must place a nil version LAST (Postgres' ASC
# default) — a divergence there would make a SQL-path caller and the serialized
# response disagree.
RSpec.describe 'BaseRule canonical ordering' do
  let_it_be(:stig) { create(:stig, :skip_rules) }

  # Created OUT of canonical order (and out of id order relative to version),
  # including a nil-version rule, so a passing test proves ordering — not
  # insertion luck.
  let_it_be(:v_mid) { create(:stig_rule, stig: stig, version: 'RHEL-09-211020') }
  let_it_be(:v_nil) { create(:stig_rule, stig: stig, version: nil) }
  let_it_be(:v_low) { create(:stig_rule, stig: stig, version: 'RHEL-09-211010') }

  let(:expected_versions) { ['RHEL-09-211010', 'RHEL-09-211020', nil] }
  let(:expected_ids)      { [v_low.id, v_mid.id, v_nil.id] }

  it 'canonical_order (SQL) orders by version then rule_id then id, NULLs last' do
    expect(stig.stig_rules.canonical_order.pluck(:version)).to eq(expected_versions)
    expect(stig.stig_rules.canonical_order.pluck(:id)).to eq(expected_ids)
  end

  it 'canonical_sort (in-memory) produces the identical order to the SQL scope' do
    loaded = stig.stig_rules.to_a # arbitrary DB order
    sorted = BaseRule.canonical_sort(loaded)

    expect(sorted.map(&:version)).to eq(expected_versions)
    expect(sorted.map(&:id)).to eq(expected_ids)
    expect(sorted.map(&:id)).to eq(stig.stig_rules.canonical_order.pluck(:id))
  end
end
