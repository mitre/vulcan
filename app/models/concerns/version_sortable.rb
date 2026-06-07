# frozen_string_literal: true

# Numeric version sorting for DISA V{major}R{minor} format.
# Replaces string-based MAX(version) which incorrectly ranks V4R4 above V10R1.
module VersionSortable
  extend ActiveSupport::Concern

  MAJOR_VERSION_SQL = "CAST(SUBSTRING(version FROM 'V(\\d+)') AS INTEGER) DESC NULLS LAST"
  MINOR_VERSION_SQL = "CAST(SUBSTRING(version FROM 'R(\\d+)') AS INTEGER) DESC NULLS LAST"

  class_methods do
    def latest_versions
      id_col = arel_table[:id]
      title_col = arel_table[:title]

      subquery = unscoped
                 .select(Arel.sql("DISTINCT ON (#{title_col.name}) #{id_col.relation.name}.#{id_col.name}"))
                 .order(
                   title_col.asc,
                   Arel.sql(MAJOR_VERSION_SQL),
                   Arel.sql(MINOR_VERSION_SQL)
                 )

      where(id: subquery)
    end
  end
end
