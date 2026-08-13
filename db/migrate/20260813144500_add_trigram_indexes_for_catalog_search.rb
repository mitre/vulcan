# frozen_string_literal: true

# The catalog rule search sections (stig_rules/srg_rules in the global
# search) match unanchored %term% ILIKE — substring semantics that
# id-fragment searches depend on (finding V-258217 by "258217"), which only
# trigram GIN indexes can serve. Indexed: the fragment-searched columns
# (ids, CCIs, check content). Title and fixtext are deliberately NOT
# trigram-indexed — they are prose searched by words, which the stored
# searchable vector already serves; the index weight is not worth covering
# mid-word fragments nobody searches there. Built concurrently so
# production writes are never blocked.
class AddTrigramIndexesForCatalogSearch < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :base_rules, :rule_id, using: :gin, opclass: :gin_trgm_ops,
                                     name: 'index_base_rules_on_rule_id_trgm', algorithm: :concurrently
    add_index :base_rules, :vuln_id, using: :gin, opclass: :gin_trgm_ops,
                                     name: 'index_base_rules_on_vuln_id_trgm', algorithm: :concurrently
    add_index :base_rules, :ident, using: :gin, opclass: :gin_trgm_ops,
                                   name: 'index_base_rules_on_ident_trgm', algorithm: :concurrently
    add_index :checks, :content, using: :gin, opclass: :gin_trgm_ops,
                                 name: 'index_checks_on_content_trgm', algorithm: :concurrently
  end
end
