# frozen_string_literal: true

# Numeric version sorting for DISA V{major}R{minor} format.
# Replaces string-based MAX(version) which incorrectly ranks V4R4 above V10R1.
module VersionSortable
  extend ActiveSupport::Concern

  class_methods do
    def latest_versions
      version_order = Arel.sql(<<~SQL.squish)
        CAST(SUBSTRING(version FROM 'V(\\d+)') AS INTEGER) DESC NULLS LAST,
        CAST(SUBSTRING(version FROM 'R(\\d+)') AS INTEGER) DESC NULLS LAST
      SQL

      subquery = unscoped
                 .select("DISTINCT ON (title) #{table_name}.id")
                 .order(Arel.sql("title, #{version_order}"))

      where(id: subquery)
    end
  end
end
