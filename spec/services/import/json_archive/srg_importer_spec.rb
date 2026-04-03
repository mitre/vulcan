# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: SrgImporter reads SRG XML files from a backup archive and
# imports any SRGs not already present on the target system. This makes
# backup archives self-contained and portable across Vulcan instances.
# ==========================================================================
RSpec.describe Import::JsonArchive::SrgImporter do
  let(:result) { Import::Result.new }
  let(:srg) { SecurityRequirementsGuide.first || create(:security_requirements_guide) }

  # Build a minimal archive hash with an srgs/ entry
  def build_archive_srgs(srg_record)
    filename = "#{srg_record.title.tr(' ', '_')}-#{srg_record.version}.xml"
    {
      manifest_srgs: [
        { 'srg_id' => srg_record.srg_id, 'title' => srg_record.title,
          'version' => srg_record.version, 'filename' => filename }
      ],
      srg_files: { filename => srg_record.xml }
    }
  end

  describe '#import_all' do
    context 'when SRG already exists on the target system' do
      it 'skips import and reports zero SRGs imported' do
        archive = build_archive_srgs(srg)
        count = described_class.new(
          manifest_srgs: archive[:manifest_srgs],
          srg_files: archive[:srg_files],
          result: result
        ).import_all

        expect(count).to eq(0)
        expect(result.success?).to be true
      end
    end

    context 'when SRG is missing from the target system' do
      it 'imports the SRG and returns count of 1' do
        # Use a real SRG XML from seeds — the importer parses srg_id/version from XML
        srg_xml_path = Rails.root.glob('db/seeds/srgs/*.xml').first.to_s
        xml = File.read(srg_xml_path)
        parsed = Xccdf::Benchmark.parse(xml)
        real_srg = SecurityRequirementsGuide.from_mapping(parsed)

        # Ensure this SRG doesn't exist on the target
        Component.where(security_requirements_guide_id:
          SecurityRequirementsGuide.where(srg_id: real_srg.srg_id, version: real_srg.version).select(:id)).destroy_all
        SecurityRequirementsGuide.where(srg_id: real_srg.srg_id, version: real_srg.version).destroy_all

        filename = 'test_srg.xml'
        manifest_srgs = [
          { 'srg_id' => real_srg.srg_id, 'title' => real_srg.title,
            'version' => real_srg.version, 'filename' => filename }
        ]

        count = described_class.new(
          manifest_srgs: manifest_srgs,
          srg_files: { filename => xml },
          result: result
        ).import_all

        expect(count).to eq(1)
        expect(SecurityRequirementsGuide.find_by(srg_id: real_srg.srg_id, version: real_srg.version)).to be_present
      end
    end

    context 'when archive has no srgs section' do
      it 'returns zero gracefully' do
        count = described_class.new(
          manifest_srgs: [],
          srg_files: {},
          result: result
        ).import_all

        expect(count).to eq(0)
      end
    end

    context 'when SRG XML is missing from archive files' do
      it 'adds a warning and skips that SRG' do
        manifest_srgs = [
          { 'srg_id' => 'SRG-FAKE-001', 'title' => 'Fake SRG', 'version' => 'V1R1',
            'filename' => 'nonexistent.xml' }
        ]
        count = described_class.new(
          manifest_srgs: manifest_srgs,
          srg_files: {},
          result: result
        ).import_all

        expect(count).to eq(0)
        expect(result.warnings).to include(match(/nonexistent\.xml/))
      end
    end
  end
end
