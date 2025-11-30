# frozen_string_literal: true

##
# Add trigram indexes for fast ILIKE searches on searchable columns
#
# PostgreSQL's pg_trgm extension enables GIN indexes that dramatically
# speed up ILIKE pattern matching. Without these indexes, ILIKE requires
# a full table scan. With GIN trigram indexes, PostgreSQL can use the
# index for pattern matching.
#
# Performance impact:
# - Small datasets (< 1000 rows): Minimal difference
# - Large datasets (10,000+ rows): 10-100x speedup for ILIKE queries
#
# These indexes support the Command Palette global search with abbreviation
# expansion (e.g., searching "RHEL" expands to also search "Red Hat Enterprise Linux")
#
class AddTrigramIndexesForSearch < ActiveRecord::Migration[8.0]
  def up
    # Enable pg_trgm extension if not already enabled
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')

    # STIGs - searched by name, title, stig_id
    add_index :stigs, :name, using: :gin, opclass: :gin_trgm_ops, name: 'index_stigs_on_name_trigram'
    add_index :stigs, :title, using: :gin, opclass: :gin_trgm_ops, name: 'index_stigs_on_title_trigram'

    # SRGs - searched by name, title, srg_id
    add_index :security_requirements_guides, :name, using: :gin, opclass: :gin_trgm_ops,
              name: 'index_srgs_on_name_trigram'
    add_index :security_requirements_guides, :title, using: :gin, opclass: :gin_trgm_ops,
              name: 'index_srgs_on_title_trigram'

    # Projects - searched by name, description
    add_index :projects, :name, using: :gin, opclass: :gin_trgm_ops, name: 'index_projects_on_name_trigram'
    # Description can be long/nullable, skip for now

    # Components - searched by name, prefix
    add_index :components, :name, using: :gin, opclass: :gin_trgm_ops, name: 'index_components_on_name_trigram'
    add_index :components, :prefix, using: :gin, opclass: :gin_trgm_ops, name: 'index_components_on_prefix_trigram'
  end

  def down
    remove_index :stigs, name: 'index_stigs_on_name_trigram', if_exists: true
    remove_index :stigs, name: 'index_stigs_on_title_trigram', if_exists: true
    remove_index :security_requirements_guides, name: 'index_srgs_on_name_trigram', if_exists: true
    remove_index :security_requirements_guides, name: 'index_srgs_on_title_trigram', if_exists: true
    remove_index :projects, name: 'index_projects_on_name_trigram', if_exists: true
    remove_index :components, name: 'index_components_on_name_trigram', if_exists: true
    remove_index :components, name: 'index_components_on_prefix_trigram', if_exists: true
  end
end
