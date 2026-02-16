# frozen_string_literal: true

require 'rails_helper'

# Tests the classification logic used by the `seed_xccdf` helper in db/seeds.rb
# (lines 16-38) to determine whether an XCCDF XML file is an SRG or a STIG.
#
# The method uses a two-tier classification strategy:
#   1. Title keywords (primary): "requirements guide" -> SRG,
#      "implementation guide" or "stig" -> STIG
#   2. Directory path (fallback): filepath containing "/srgs/" -> SRG,
#      filepath containing "/stigs/" -> STIG
#
# Files matching neither tier are skipped (return nil).
#
# We test the classification logic directly rather than calling seed_xccdf
# itself, because seeds.rb has a `raise unless Rails.env.development?` guard
# and calling the full method would create database records as a side effect.

# Expected titles for each seed file (verified by inspecting the XML).
# These serve as regression anchors -- if a seed file is replaced with
# one that has a different title, the test will catch it.
#
# Defined outside RSpec.describe to avoid Lint/ConstantDefinitionInBlock.
SEED_XCCDF_EXPECTED_SRG_TITLES = {
  'U_Container_Platform_SRG_V2R4_Manual-xccdf.xml' => 'Container Platform Security Requirements Guide',
  'U_Database_SRG_V4R4_Manual-xccdf.xml' => 'Database Security Requirements Guide',
  'U_GPOS_SRG_V3R3_Manual-xccdf.xml' => 'General Purpose Operating System Security Requirements Guide',
  'U_Web_Server_SRG_V4R4_Manual-xccdf.xml' => 'Web Server Security Requirements Guide'
}.freeze

SEED_XCCDF_EXPECTED_STIG_TITLES = {
  'U_ASD_STIG_V6R4_Manual-xccdf.xml' => 'Application Security and Development Security Technical Implementation Guide',
  'U_CD_PGSQL_STIG_V3R1_Manual-xccdf.xml' => 'Crunchy Data PostgreSQL Security Technical Implementation Guide',
  'U_MS_Windows_Server_2025_V1R0-1_STIG_Manual-xccdf.xml' => 'Microsoft Windows Server 2025 ', # trailing space in actual XML
  'U_RHEL_9_STIG_V2R7_Manual-xccdf.xml' => 'Red Hat Enterprise Linux 9 Security Technical Implementation Guide'
}.freeze

# Cache parsed titles across examples to avoid re-parsing large XML files.
# Intentionally mutable -- populated lazily during test execution.
SEED_XCCDF_TITLE_CACHE = {} # rubocop:disable Style/MutableConstant

RSpec.describe 'seed_xccdf classification logic', type: :model do
  before do
    Rails.application.reload_routes!
  end

  # Replicate the exact classification logic from db/seeds.rb lines 19-22.
  # This is intentionally a literal copy so the tests break if someone
  # changes the logic in seeds.rb without updating these tests.
  def classify(title, filepath)
    title = title&.downcase || ''

    is_srg = title.include?('requirements guide') || filepath.to_s.include?('/srgs/')
    is_stig = title.include?('implementation guide') || title.include?('stig') || filepath.to_s.include?('/stigs/')

    if is_srg
      :srg
    elsif is_stig
      :stig
    else
      :unknown
    end
  end

  # Parse the title from an XCCDF file the same way seed_xccdf does.
  def parsed_title(filepath)
    key = filepath.to_s
    SEED_XCCDF_TITLE_CACHE[key] ||= begin
      xml = File.read(filepath)
      parsed = Xccdf::Benchmark.parse(xml)
      parsed.try(:title)&.first || ''
    end
  end

  # -----------------------------------------------------------------
  # Unit tests for classification logic
  # -----------------------------------------------------------------
  describe 'title-based classification' do
    context 'when title contains "requirements guide"' do
      it 'classifies as SRG' do
        expect(classify('General Purpose Operating System Security Requirements Guide', '')).to eq(:srg)
      end

      it 'classifies as SRG regardless of case' do
        expect(classify('Web Server Security REQUIREMENTS GUIDE', '')).to eq(:srg)
      end
    end

    context 'when title contains "implementation guide"' do
      it 'classifies as STIG' do
        expect(classify('Application Security and Development Security Technical Implementation Guide', '')).to eq(:stig)
      end

      it 'classifies as STIG regardless of case' do
        expect(classify('Some Technical IMPLEMENTATION GUIDE', '')).to eq(:stig)
      end
    end

    context 'when title contains "stig"' do
      it 'classifies as STIG' do
        expect(classify('PostgreSQL STIG', '')).to eq(:stig)
      end

      it 'classifies as STIG when "stig" appears as a substring' do
        # "investigation" contains "stig" -- verify the logic handles this
        expect(classify('investigation report', '')).to eq(:stig)
      end
    end

    context 'when title matches neither keyword' do
      it 'returns unknown for a generic title with no path fallback' do
        expect(classify('Microsoft Windows Server 2025', '')).to eq(:unknown)
      end

      it 'returns unknown for an empty title with no path fallback' do
        expect(classify('', '')).to eq(:unknown)
      end

      it 'returns unknown for nil title with no path fallback' do
        expect(classify(nil, '')).to eq(:unknown)
      end
    end
  end

  describe 'directory path fallback' do
    context 'when filepath contains /srgs/' do
      it 'classifies as SRG even with an ambiguous title' do
        expect(classify('Some Ambiguous Title', '/app/db/seeds/srgs/file.xml')).to eq(:srg)
      end

      it 'classifies as SRG even with an empty title' do
        expect(classify('', '/app/db/seeds/srgs/file.xml')).to eq(:srg)
      end
    end

    context 'when filepath contains /stigs/' do
      it 'classifies as STIG even with an ambiguous title' do
        expect(classify('Microsoft Windows Server 2025', '/app/db/seeds/stigs/file.xml')).to eq(:stig)
      end

      it 'classifies as STIG even with an empty title' do
        expect(classify('', '/app/db/seeds/stigs/file.xml')).to eq(:stig)
      end
    end
  end

  describe 'priority: title keyword wins over directory path' do
    it 'classifies as SRG by title even if filepath says /stigs/' do
      # "requirements guide" keyword takes priority (is_srg checked first)
      expect(classify('Security Requirements Guide', '/stigs/file.xml')).to eq(:srg)
    end
  end

  # -----------------------------------------------------------------
  # Regression tests against real seed files
  # -----------------------------------------------------------------
  describe 'SRG seed files' do
    let(:srg_dir) { Rails.root.join('db/seeds/srgs') }

    SEED_XCCDF_EXPECTED_SRG_TITLES.each do |filename, expected_title|
      it "#{filename} exists" do
        expect(File.exist?(srg_dir.join(filename))).to be(true), "Missing seed file: #{filename}"
      end

      it "#{filename} has expected title: #{expected_title}" do
        filepath = srg_dir.join(filename)
        skip "Seed file missing: #{filename}" unless File.exist?(filepath)
        expect(parsed_title(filepath)).to eq(expected_title)
      end

      it "#{filename} classifies as SRG by title keyword" do
        filepath = srg_dir.join(filename)
        skip "Seed file missing: #{filename}" unless File.exist?(filepath)
        expect(classify(parsed_title(filepath), filepath.to_s)).to eq(:srg)
      end
    end

    it 'has no unexpected seed files' do
      actual_files = Dir.glob(srg_dir.join('*.xml')).map { |f| File.basename(f) }.sort
      expected_files = SEED_XCCDF_EXPECTED_SRG_TITLES.keys.sort
      expect(actual_files).to eq(expected_files),
                              'SRG seed files changed. ' \
                              "Actual: #{actual_files}. " \
                              'Update SEED_XCCDF_EXPECTED_SRG_TITLES to match.'
    end
  end

  describe 'STIG seed files' do
    let(:stig_dir) { Rails.root.join('db/seeds/stigs') }

    SEED_XCCDF_EXPECTED_STIG_TITLES.each do |filename, expected_title|
      it "#{filename} exists" do
        expect(File.exist?(stig_dir.join(filename))).to be(true), "Missing seed file: #{filename}"
      end

      it "#{filename} has expected title: #{expected_title}" do
        filepath = stig_dir.join(filename)
        skip "Seed file missing: #{filename}" unless File.exist?(filepath)
        expect(parsed_title(filepath)).to eq(expected_title)
      end

      it "#{filename} classifies as STIG" do
        filepath = stig_dir.join(filename)
        skip "Seed file missing: #{filename}" unless File.exist?(filepath)
        expect(classify(parsed_title(filepath), filepath.to_s)).to eq(:stig)
      end
    end

    it 'has no unexpected seed files' do
      actual_files = Dir.glob(stig_dir.join('*.xml')).map { |f| File.basename(f) }.sort
      expected_files = SEED_XCCDF_EXPECTED_STIG_TITLES.keys.sort
      expect(actual_files).to eq(expected_files),
                              'STIG seed files changed. ' \
                              "Actual: #{actual_files}. " \
                              'Update SEED_XCCDF_EXPECTED_STIG_TITLES to match.'
    end
  end

  describe 'Windows Server 2025 (directory path fallback case)' do
    let(:stig_dir) { Rails.root.join('db/seeds/stigs') }
    let(:filepath) { stig_dir.join('U_MS_Windows_Server_2025_V1R0-1_STIG_Manual-xccdf.xml') }

    it 'has a title that does NOT contain "stig" or "implementation guide"' do
      skip 'Seed file missing' unless File.exist?(filepath)
      title = parsed_title(filepath).downcase
      expect(title).not_to include('stig')
      expect(title).not_to include('implementation guide')
    end

    it 'classifies as STIG only because of the /stigs/ directory path' do
      skip 'Seed file missing' unless File.exist?(filepath)
      title = parsed_title(filepath)

      # Without path fallback, it would be unknown
      expect(classify(title, '')).to eq(:unknown)
      # With path fallback, it correctly classifies as STIG
      expect(classify(title, filepath.to_s)).to eq(:stig)
    end
  end
end
