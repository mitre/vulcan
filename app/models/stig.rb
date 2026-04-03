# frozen_string_literal: true

# Stig Model
class Stig < ApplicationRecord
  include SeverityCounts
  include XccdfParseable
  include BenchmarkCsvExport

  has_many :stig_rules, dependent: :destroy

  validates :stig_id, :title, :name, :version, :xml, presence: true
  validates :stig_id, uniqueness: {
    scope: :version,
    message: 'ID has already been taken'
  }
  # Length limits — configurable via Settings.input_limits (env vars: VULCAN_LIMIT_*)
  validates :stig_id, :version,
            length: { maximum: ->(_r) { Settings.input_limits.short_string } }
  validates :title, length: { maximum: ->(_r) { Settings.input_limits.benchmark_title } }
  validates :name, length: { maximum: ->(_r) { Settings.input_limits.benchmark_name } }
  validates :description, length: { maximum: ->(_r) { Settings.input_limits.benchmark_description } }, allow_nil: true

  after_create :import_stig_rules
  # STIG parameter is the entire parsed benchmark
  def self.from_mapping(benchmark_mapping)
    id = benchmark_mapping&.id
    title = benchmark_mapping&.title&.first
    version = "V#{benchmark_mapping&.version&.version}" \
              "#{SecurityRequirementsGuide.revision(benchmark_mapping.plaintext.first)}"
    benchmark_date = SecurityRequirementsGuide.release_date(benchmark_mapping.plaintext.first)
    description = benchmark_mapping&.description&.first
    name = id&.tr('_', ' ')&.gsub(/(?<=\d)-/, '.')
    name = "#{name} - Ver #{version.to_s[1]}, Rel #{version.to_s.last}"

    Stig.new(stig_id: id, title: title, name: name, version: version, description: description,
             benchmark_date: benchmark_date)
  end

  ##
  # Override for SeverityCounts and BenchmarkCsvExport - specify rules association
  def rules_association
    stig_rules
  end

  private

  def import_stig_rules
    stig_rules = parsed_benchmark.group.map { |grp| StigRule.from_mapping(grp, id) }.sort_by(&:version)

    # Examine import results for failures
    failures = StigRule.import(stig_rules, all_or_none: true, recursive: true).failed_instances
    if failures.empty?
      reload
    else
      detail = failures.first(3).map { |r| "#{r.rule_id}: #{r.errors.full_messages.join(', ')}" }.join('; ')
      detail += " (and #{failures.size - 3} more)" if failures.size > 3
      errors.add(:base, "#{failures.size} rules failed to import: #{detail}")
      raise ActiveRecord::Rollback
    end
  end
end
