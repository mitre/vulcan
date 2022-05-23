# frozen_string_literal: true

# SecurityRequirementsGuides (abbreviated SRGs) are XCCDF documents that contain a
# benchmark that describes how to evaluate generic IT systems.
class SecurityRequirementsGuide < ApplicationRecord
  has_many :components, dependent: :restrict_with_error
  has_many :srg_rules, dependent: :destroy

  after_create :import_srg_rules

  validates :srg_id, :title, :version, :xml, presence: true
  validates :srg_id, uniqueness: {
    scope: :version,
    message: ' ID has already been taken'
  }

  # Since an SRG is top-level, the parameter is the entire parsed benchmark
  def self.from_mapping(benchmark_mapping)
    # Disabling `Style/RescueModifier` here because the goal is simply just to try and
    # fetch the attribute, but return `nil` if anything goes wrong with parsing.
    # rubocop:disable Style/RescueModifier
    id = benchmark_mapping.id rescue nil
    title = benchmark_mapping.title.first rescue nil
    version = "V#{benchmark_mapping.version.version}" \
              "#{SecurityRequirementsGuide.revision(benchmark_mapping.plaintext.first)}" rescue nil
    release_date = SecurityRequirementsGuide.release_date(benchmark_mapping.plaintext.first)
    # rubocop:enable Style/RescueModifier

    SecurityRequirementsGuide.new(srg_id: id, title: title, version: version, release_date: release_date)
  end

  # If the SRGs do not conform nicely and this function gets complex, remove the version parse logic
  # and do not display detailed version information. Make SRG producers actually provide consistent
  # metadata.
  def self.revision(plaintext_mapping)
    revision_string = plaintext_mapping.plaintext.split('Release: ')[1]
    return '' if revision_string.nil?

    "R#{revision_string.match(/^\d+/)[0]}"
  end

  def self.release_date(plaintext_mapping)
    release_date_string = plaintext_mapping.plaintext.split('Benchmark Date: ')[1]
    return '' if release_date_string.nil?

    begin
      Date.parse(release_date_string)
    rescue Date::Error
      ''
    end
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
    SecurityRequirementsGuide.connection.execute(Arel.sql(query)).to_a
  end

  def full_title
    "#{title} #{version}"
  end

  def parsed_benchmark
    @parsed_benchmark ||= Xccdf::Benchmark.parse(xml)
  end

  attr_writer :parsed_benchmark

  private

  def import_srg_rules
    srg_rules = parsed_benchmark.rule.map { |rule| SrgRule.from_mapping(rule, id) }.sort_by(&:version)

    # Examine import results for failures
    failures = SrgRule.import(srg_rules, all_or_none: true, recursive: true).failed_instances
    if failures.empty?
      reload
    else
      errors.add(:base, 'Some rules failed to import successfully for the SRG.')
      raise ActiveRecord::Rollback
    end
  end
end
