# frozen_string_literal: true

# SecurityRequirementsGuides (abbreviated SRGs) are XCCDF documents that contain a
# benchmark that describes how to evaluate generic IT systems.
class SecurityRequirementsGuide < ApplicationRecord
  has_many :projects, dependent: :restrict_with_error

  validates :srg_id, :title, :version, :xml, presence: true
  validates :srg_id, uniqueness: {
    scope: :version,
    message: ' ID has already been taken'
  }

  # Since an SRG is top-level, the parameter is the entire parsed benchmark
  def self.from_mapping(benchmark_mapping)
    SecurityRequirementsGuide.new(
      srg_id: benchmark_mapping.id,
      title: benchmark_mapping.title.first,
      version: "V#{benchmark_mapping.version.version}" \
               "#{SecurityRequirementsGuide.revision(benchmark_mapping.plaintext.first)}"
    )
  end

  # If the SRGs do not conform nicely and this function gets complex, remove the version parse logic
  # and do not display detailed version information. Make SRG producers actually provide consistent
  # metadata.
  def self.revision(plaintext_mapping)
    revision_string = plaintext_mapping.plaintext.split('Release: ')[1]
    return '' if revision_string.nil?

    "R#{revision_string.match(/^\d+/)[0]}"
  end

  def self.latest
    query = <<-SQL.squish
      SELECT id, title, version
      FROM security_requirements_guides
      WHERE version IN (
          SELECT MAX(version)
          FROM security_requirements_guides
          GROUP BY title
      )
    SQL
    SecurityRequirementsGuide.connection.execute(Arel.sql(query)).map { |r| r }
  end

  def full_title
    "#{title} #{version}"
  end
end
