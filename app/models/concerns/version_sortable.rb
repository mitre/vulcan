# frozen_string_literal: true

# Numeric version sorting for DISA V{major}R{minor} format.
# Replaces string-based MAX(version) which incorrectly ranks V4R4 above V10R1.
#
# The stable key across releases of one document (its release line) is the
# XCCDF benchmark id — identical across major and minor releases (verified
# against real DISA release history). A DISA rename changes the id and
# title together and legitimately starts a NEW document line, so staleness
# does not fire across renames. Titles may be reworded between releases and
# are display, never identity.
module VersionSortable
  extend ActiveSupport::Concern

  MAJOR_VERSION_SQL = "CAST(SUBSTRING(version FROM 'V(\\d+)') AS INTEGER) DESC NULLS LAST"
  MINOR_VERSION_SQL = "CAST(SUBSTRING(version FROM 'R(\\d+)') AS INTEGER) DESC NULLS LAST"

  included do
    # The benchmark-id column of the including model (:srg_id / :stig_id).
    class_attribute :series_key_column, instance_writer: false
  end

  def latest?
    self.class.latest_versions.exists?(id: id)
  end

  def latest_release
    self.class
        .where(series_key_column => public_send(series_key_column))
        .order(
          Arel.sql(VersionSortable::MAJOR_VERSION_SQL),
          Arel.sql(VersionSortable::MINOR_VERSION_SQL)
        )
        .first
  end

  class_methods do
    def latest_versions
      id_col = arel_table[:id]
      series_col = arel_table[series_key_column]

      subquery = unscoped
                 .select(Arel.sql("DISTINCT ON (#{series_col.name}) #{id_col.relation.name}.#{id_col.name}"))
                 .order(
                   series_col.asc,
                   Arel.sql(MAJOR_VERSION_SQL),
                   Arel.sql(MINOR_VERSION_SQL)
                 )

      where(id: subquery)
    end
  end
end
