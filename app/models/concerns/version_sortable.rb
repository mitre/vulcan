# frozen_string_literal: true

# Numeric version sorting for DISA V{major}R{minor} format.
# Replaces string-based MAX(version) which incorrectly ranks V4R4 above V10R1.
#
# The stable FAMILY key across releases is the XCCDF benchmark id — it is
# identical across major and minor releases of one document (verified
# against real DISA release history). A DISA rename changes the id and
# title together and legitimately starts a NEW family, so staleness does
# not fire across renames. Titles may be reworded mid-family and are
# display, never identity.
module VersionSortable
  extend ActiveSupport::Concern

  MAJOR_VERSION_SQL = "CAST(SUBSTRING(version FROM 'V(\\d+)') AS INTEGER) DESC NULLS LAST"
  MINOR_VERSION_SQL = "CAST(SUBSTRING(version FROM 'R(\\d+)') AS INTEGER) DESC NULLS LAST"

  included do
    # The benchmark-id column of the including model (:srg_id / :stig_id).
    class_attribute :version_family_column, instance_writer: false
  end

  def latest?
    self.class.latest_versions.exists?(id: id)
  end

  def latest_for_family
    self.class
        .where(version_family_column => public_send(version_family_column))
        .order(
          Arel.sql(VersionSortable::MAJOR_VERSION_SQL),
          Arel.sql(VersionSortable::MINOR_VERSION_SQL)
        )
        .first
  end

  class_methods do
    def latest_versions
      id_col = arel_table[:id]
      family_col = arel_table[version_family_column]

      subquery = unscoped
                 .select(Arel.sql("DISTINCT ON (#{family_col.name}) #{id_col.relation.name}.#{id_col.name}"))
                 .order(
                   family_col.asc,
                   Arel.sql(MAJOR_VERSION_SQL),
                   Arel.sql(MINOR_VERSION_SQL)
                 )

      where(id: subquery)
    end
  end
end
