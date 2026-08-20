# frozen_string_literal: true

# Persisted source of truth for whether an authored requirement has had its
# final derived identifier minted at release, and which document-wide local
# sequence it received. Replaces string-shape recognition in
# ReleaseIdentifierMinter, which cannot distinguish a raw multi-segment SRG
# core (SRG-APP-000014-CTR-000035) from a minted identifier once cores vary
# in length — the ambiguity that let 5-segment-core rows be renumbered on
# re-release. NULL means not minted; a non-NULL value is the row's stamped
# sequence. Lives on base_rules (STI) but only authored SrgRule rows use it.
class AddMintedSequenceToBaseRules < ActiveRecord::Migration[8.0]
  def change
    add_column :base_rules, :minted_sequence, :integer
  end
end
