# frozen_string_literal: true

XML_FILE = Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read

# Stamps the factory's identity attributes into the GPOS fixture's header
# so factory rows satisfy the row-XML consistency validation (columns must
# match the stored document's header). Raises if any target string is
# absent — a future fixture swap must fail loudly, never stamp silently
# wrong.
module SrgFactoryXml
  HEADER_TARGETS = {
    benchmark_id: 'id="General_Purpose_Operating_System"',
    title: '<title>General Purpose Operating System Security Requirements Guide</title>',
    version: '<version>3</version>',
    release_info: 'Release: 3 Benchmark Date: 28 Oct 2025'
  }.freeze

  def self.stamp_header(xml, srg_id:, title:, version:, release_date:)
    match = version.to_s.match(/\AV(\d+)R(\d+)\z/)
    raise ArgumentError, "factory version #{version.inspect} is not V{n}R{n} — cannot stamp the XML header" unless match

    date = (release_date || Date.new(2025, 10, 28)).strftime('%-d %b %Y')
    replacements = {
      HEADER_TARGETS[:benchmark_id] => %(id="#{srg_id}"),
      HEADER_TARGETS[:title] => "<title>#{title}</title>",
      HEADER_TARGETS[:version] => "<version>#{match[1]}</version>",
      HEADER_TARGETS[:release_info] => "Release: #{match[2]} Benchmark Date: #{date}"
    }
    replacements.reduce(xml) do |stamped, (target, replacement)|
      raise "GPOS fixture header changed — update SrgFactoryXml::HEADER_TARGETS (#{target.inspect} not found)" unless
        stamped.include?(target)

      stamped.sub(target, replacement)
    end
  end
end

FactoryBot.define do
  factory :security_requirements_guide do
    sequence(:srg_id) { |n| "SRG-TEST-#{n.to_s.rjust(6, '0')}" }
    title { "Test Security Requirements Guide #{srg_id}" }
    sequence(:version) { |n| "V#{(n / 10) + 1}R#{(n % 10) + 1}" }
    xml do
      SrgFactoryXml.stamp_header(XML_FILE, srg_id: srg_id, title: title,
                                           version: version, release_date: release_date)
    end
    release_date { Time.zone.today }

    # A core SRG — the non-public raw material SRG-kind components
    # derive from (never a valid STIG parent).
    trait :core do
      core { true }
    end

    # Lightweight SRG that skips the ~250 rule import from the XML fixture.
    # Use when tests hand-craft srg_rules (e.g., pinning severity counts).
    # Uses the production intent flag — the same seam the release path uses.
    trait :skip_rules do
      skip_rule_import { true }
    end
  end
end
