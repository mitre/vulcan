# frozen_string_literal: true

# SecurityRequirementsGuides (abbreviated SRGs) are XCCDF documents that contain a
# benchmark that describes how to evaluate generic IT systems.
class SecurityRequirementsGuide < ApplicationRecord
  include SeverityCounts
  include XccdfParseable
  include BenchmarkCsvExport
  include VersionSortable
  include BenchmarkSearchable

  self.series_key_column = :srg_id

  # The core SRGs are DEFINED — exactly three, DISA-published (Operating
  # System Core, Network Core, Application Core). Core-ness is recognition
  # of those documents by benchmark id, never a user designation. DISA's
  # own naming is inconsistent (two ids end _SRG, one does not) — these
  # values are read from the published documents.
  CORE_SRG_IDS = %w[Operating_System_Core Network_Core_SRG Application_Core_SRG].freeze

  def self.search_columns
    %w[name title srg_id]
  end

  has_many :components, dependent: :restrict_with_error
  has_many :srg_rules, dependent: :destroy

  # Release-path intent flag: catalog rows created at release get their
  # rules from the release copy, never the XML import.
  attr_accessor :skip_rule_import

  # One-directional: a matching benchmark id flags the record core; a
  # non-matching id never unsets an explicitly-set core (scratch and
  # walkthrough cores use arbitrary ids). The model is the ONE recognition
  # seam — every creation path (upload, seeds, release attachment) passes
  # through it.
  before_validation :recognize_core_document, on: :create

  after_create :import_srg_rules, unless: :skip_rule_import

  validates :srg_id, :title, :version, :xml, presence: true
  validate :header_must_match_columns, if: -> { xml.present? && will_save_change_to_xml? }
  validates :srg_id, uniqueness: {
    scope: :version,
    message: ' ID has already been taken'
  }
  # Length limits — configurable via Settings.input_limits (env vars: VULCAN_LIMIT_*)
  validates :srg_id, :version,
            length: { maximum: ->(_r) { Settings.input_limits.short_string } }
  validates :title, length: { maximum: ->(_r) { Settings.input_limits.benchmark_title } }
  validates :name, length: { maximum: ->(_r) { Settings.input_limits.benchmark_name } }, allow_nil: true

  def self.srg_info_for_components(components)
    latest_ids = latest_versions.pluck(:id).to_set
    # Currency covers the WHOLE parent set (title/version stay the
    # primary's — display); one batched join-row query for all components.
    parent_map = ComponentSourceSrg.where(component_id: components.map(&:id))
                                   .pluck(:component_id, :security_requirements_guide_id)
                                   .group_by(&:first)
                                   .transform_values { |rows| rows.map(&:last) }
    components.each_with_object({}) do |c, map|
      srg = c.based_on
      next unless srg

      parent_ids = parent_map[c.id] || [srg.id]
      map[c.id] = { title: srg.title, version: srg.version,
                    is_latest: parent_ids.all? { |pid| latest_ids.include?(pid) } }
    end
  end

  # ---- Shared header composition rules -------------------------------
  # The ONE home for each formula: upload (from_mapping, here and on
  # Stig), export (XccdfFormatter#benchmark_id), and the release
  # attachment all call these — no second copy may exist anywhere.

  def self.version_string(version, release)
    "V#{version}R#{release}"
  end

  def self.display_name(srg_id, version)
    base = srg_id.tr('_', ' ').gsub(/(?<=\d)-/, '.')
    match = version.to_s.match(/\AV(\d+)R(\d+)\z/)
    return base unless match

    "#{base} - Ver #{match[1]}, Rel #{match[2]}"
  end

  def self.srg_id_from_name(name)
    name.tr(' ', '_')
  end

  # Light header read of an XCCDF string — identity fields only, never
  # the full rule parse. The shared extractor behind the row-XML
  # consistency validation and the release attachment: the stored
  # document is authoritative, the columns are its projection.
  def self.header_fields(xml)
    header = Xccdf::BenchmarkHeader.parse(xml)
    release = release_number(header.release_info)
    {
      srg_id: header.benchmark_id,
      title: header.title,
      version: header.version.presence && release && version_string(header.version, release),
      release_date: release_date(header.release_info).presence
    }
  end

  # Since an SRG is top-level, the parameter is the entire parsed benchmark
  def self.from_mapping(benchmark_mapping)
    # Fetch attributes defensively — nil pieces are rejected downstream
    # by the presence validations, never silently defaulted.
    # rubocop:disable Style/RescueModifier
    id = benchmark_mapping.id rescue nil
    title = benchmark_mapping.title.first rescue nil
    release_info = benchmark_mapping.plaintext.first&.plaintext rescue nil
    release = release_number(release_info)
    version = release && version_string(benchmark_mapping.version.version, release) rescue nil
    # rubocop:enable Style/RescueModifier
    SecurityRequirementsGuide.new(srg_id: id, title: title, name: id && display_name(id, version),
                                  version: version, release_date: release_date(release_info))
  end

  # If the SRGs do not conform nicely and this function gets complex, remove the version parse logic
  # and do not display detailed version information. Make SRG producers actually provide consistent
  # metadata.
  def self.release_number(release_info)
    release_info.to_s.split('Release: ')[1]&.match(/^\d+/)&.[](0)
  end

  def self.release_date(release_info)
    release_date_string = release_info.to_s.split('Benchmark Date: ')[1]
    return '' if release_date_string.nil?

    begin
      Date.parse(release_date_string)
    rescue Date::Error
      ''
    end
  end

  def self.latest
    latest_versions.select(:id, :title, :version).to_a
  end

  def full_title
    "#{title} #{version}"
  end

  ##
  # Override for SeverityCounts and BenchmarkCsvExport - specify rules association
  def rules_association
    srg_rules
  end

  ##
  # Override for BenchmarkCsvExport - provide default columns
  def default_columns
    ExportConstants::SRG_CSV_DEFAULT_COLUMNS
  end

  ##
  # Override for BenchmarkCsvExport - provide header overrides
  def header_overrides
    ExportConstants::SRG_CSV_HEADER_OVERRIDES
  end

  private

  def recognize_core_document
    self.core = true if CORE_SRG_IDS.include?(srg_id)
  end

  # The stored document is authoritative — backup restore re-derives rows
  # from it, so a row whose columns disagree with its own XML header
  # would change identity across a backup cycle. Reject the write.
  def header_must_match_columns
    header = SecurityRequirementsGuide.header_fields(xml)
    { srg_id: srg_id, title: title, version: version }.each do |field, column_value|
      next if column_value == header[field]

      errors.add(field, 'does not match the stored XCCDF header ' \
                        "(column: #{column_value.inspect}, header: #{header[field].inspect})")
    end
  end

  def import_srg_rules
    srg_rules = parsed_benchmark.rule.map { |rule| SrgRule.from_mapping(rule, id) }.sort_by(&:version)

    # Examine import results for failures
    failures = SrgRule.import(srg_rules, all_or_none: true, recursive: true).failed_instances
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
