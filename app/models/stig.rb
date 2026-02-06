# frozen_string_literal: true

# Stig Model
class Stig < ApplicationRecord
  has_many :stig_rules, dependent: :destroy

  validates :stig_id, :title, :name, :version, :xml, presence: true
  validates :stig_id, uniqueness: {
    scope: :version,
    message: 'ID has already been taken'
  }

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

  def parsed_benchmark
    Xccdf::Benchmark.parse(xml)
  end

  # Generate CSV export with configurable columns
  # columns: array of column keys (symbols), defaults to BENCHMARK_CSV_DEFAULT_COLUMNS
  def csv_export(columns: nil)
    columns ||= ExportConstants::BENCHMARK_CSV_DEFAULT_COLUMNS
    headers = columns.map { |key| ExportConstants::BENCHMARK_CSV_COLUMNS[key][:header] }

    ::CSV.generate(headers: true) do |csv|
      csv << headers
      stig_rules.eager_load(:disa_rule_descriptions, :checks)
                .order(:version, :rule_id)
                .each do |rule|
        csv << columns.map { |key| rule.csv_value_for(key) }
      end
    end
  end

  private

  def import_stig_rules
    stig_rules = parsed_benchmark.group.map { |grp| StigRule.from_mapping(grp, id) }.sort_by(&:version)

    # Examine import results for failures
    failures = StigRule.import(stig_rules, all_or_none: true, recursive: true).failed_instances
    if failures.empty?
      reload
    else
      errors.add(:base, 'Some rules failed to import successfully for the SRG.')
      raise ActiveRecord::Rollback
    end
  end
end
