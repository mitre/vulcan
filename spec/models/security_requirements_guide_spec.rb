# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SecurityRequirementsGuide do
  let_it_be(:srg) { create(:security_requirements_guide) }

  # ==========================================================================
  # REQUIREMENT: the three header composition rules — version string,
  # display name, benchmark-id underscoring — each live in exactly ONE
  # shared class method. Upload (from_mapping), export, and release all
  # call these; no second copy of any formula may exist.
  # ==========================================================================
  describe 'shared header composition rules' do
    it 'composes the V{version}R{release} version string' do
      expect(described_class.version_string(3, 3)).to eq('V3R3')
      expect(described_class.version_string(10, 12)).to eq('V10R12')
    end

    it 'composes the display name from srg_id and version' do
      expect(described_class.display_name('General_Purpose_Operating_System', 'V3R3'))
        .to eq('General Purpose Operating System - Ver 3, Rel 3')
    end

    it 'keeps whole multi-digit numbers in the display name' do
      expect(described_class.display_name('General_Purpose_Operating_System', 'V10R12'))
        .to eq('General Purpose Operating System - Ver 10, Rel 12')
    end

    it 'omits the Ver/Rel suffix when the version does not parse' do
      expect(described_class.display_name('Web_Server_SRG', nil)).to eq('Web Server SRG')
    end

    it 'derives the benchmark id by underscoring the name' do
      expect(described_class.srg_id_from_name('Container Best Practice SRG'))
        .to eq('Container_Best_Practice_SRG')
    end
  end

  # ==========================================================================
  # REQUIREMENT: a light header reader returns the identity fields from an
  # XCCDF string without the full rule parse — the shared extractor behind
  # the row-XML consistency invariant. Pinned to the GPOS seed's known
  # header values.
  # ==========================================================================
  describe '.header_fields' do
    let(:gpos_xml) { Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read }

    it 'reads srg_id, title, version, and release date from the GPOS seed' do
      fields = described_class.header_fields(gpos_xml)
      expect(fields[:srg_id]).to eq('General_Purpose_Operating_System')
      expect(fields[:title]).to eq('General Purpose Operating System Security Requirements Guide')
      expect(fields[:version]).to eq('V3R3')
      expect(fields[:release_date]).to eq(Date.new(2025, 10, 28))
    end

    it 'returns nil fields for unparseable XML instead of raising' do
      expect(described_class.header_fields('not xml at all')).to eq(
        srg_id: nil, title: nil, version: nil, release_date: nil
      )
    end
  end

  # ==========================================================================
  # REQUIREMENT: the row-XML consistency invariant — a row whose identity
  # columns disagree with the header of its own stored XCCDF is rejected.
  # Backup restore re-derives rows from stored XML, so a mismatch would
  # silently change a document's identity across a backup cycle.
  # ==========================================================================
  describe 'row-XML header consistency validation' do
    it 'accepts a row whose columns match its stored XML header' do
      expect(build(:security_requirements_guide, srg_id: 'SRG-CONS-PASS', version: 'V2R5')).to be_valid
    end

    it 'rejects a row whose version disagrees with the stored XML header' do
      row = build(:security_requirements_guide, srg_id: 'SRG-CONS-VER', version: 'V2R5')
      row.version = 'V9R9'
      expect(row).not_to be_valid
      expect(row.errors[:version].join).to include('does not match the stored XCCDF header')
    end

    it 'rejects a row whose srg_id disagrees with the stored XML header' do
      row = build(:security_requirements_guide, srg_id: 'SRG-CONS-ID', version: 'V2R5')
      row.srg_id = 'SRG-SOMETHING-ELSE'
      expect(row).not_to be_valid
      expect(row.errors[:srg_id].join).to include('does not match the stored XCCDF header')
    end

    it 'only checks the header when the XML itself is new or changing' do
      row = create(:security_requirements_guide, :skip_rules, srg_id: 'SRG-CONS-GUARD', version: 'V2R5')
      row.update_column(:version, 'V9R9')
      expect(row.reload.update(name: 'renamed without touching xml')).to be(true)
    end
  end

  # ==========================================================================
  # REQUIREMENT: the release path creates catalog rows whose rules come
  # from the release copy, never the XML import — an intent flag skips
  # the after_create import without touching the upload path.
  # ==========================================================================
  describe 'skip_rule_import' do
    it 'imports every rule from the XML by default' do
      expect(srg.srg_rules.count).to eq(203)
    end

    it 'imports nothing when the intent flag is set' do
      skipped = create(:security_requirements_guide, skip_rule_import: true,
                                                     srg_id: 'SRG-SKIP-TEST', version: 'V3R1')
      expect(skipped.srg_rules.count).to eq(0)
    end
  end

  context 'severity_counts' do
    it 'returns aggregated severity counts' do
      counts = srg.severity_counts
      expect(counts).to be_a(Hash)
      expect(counts.keys).to contain_exactly(:high, :medium, :low)
      expect(counts[:high]).to be >= 0
      expect(counts[:medium]).to be >= 0
      expect(counts[:low]).to be >= 0
    end

    it 'includes severity_counts in as_json when requested' do
      json = srg.as_json(methods: [:severity_counts])
      expect(json['severity_counts']).to be_a(Hash)
    end
  end

  context 'with_severity_counts scope' do
    it 'adds severity count virtual columns' do
      loaded_srg = SecurityRequirementsGuide.with_severity_counts.find(srg.id)
      expect(loaded_srg).to respond_to(:severity_high_count)
      expect(loaded_srg).to respond_to(:severity_medium_count)
      expect(loaded_srg).to respond_to(:severity_low_count)
    end

    it 'counts match direct queries', :aggregate_failures do
      loaded_srg = SecurityRequirementsGuide.with_severity_counts.find(srg.id)

      # Verify counts match direct rule queries
      expected_high = srg.srg_rules.where(rule_severity: 'high').count
      expected_medium = srg.srg_rules.where(rule_severity: 'medium').count
      expected_low = srg.srg_rules.where(rule_severity: 'low').count

      expect(loaded_srg.severity_high_count).to eq(expected_high)
      expect(loaded_srg.severity_medium_count).to eq(expected_medium)
      expect(loaded_srg.severity_low_count).to eq(expected_low)
    end
  end

  describe '.currency_for' do
    it 'derives is_latest and the latest-available pointer for a whole set in ONE query' do
      v1 = create(:security_requirements_guide, :skip_rules, srg_id: 'SRG-CUR-A', version: 'V1R1')
      v2 = create(:security_requirements_guide, :skip_rules, srg_id: 'SRG-CUR-A', version: 'V2R1')

      report = count_queries { @currency = described_class.currency_for([v1, v2]) }

      # One batched latest-per-series query — not a DISTINCT ON subquery per row.
      expect(report.total).to eq(1)
      expect(@currency[v2.id]).to eq(is_latest: true, latest_available_version: nil, latest_available_id: nil)
      expect(@currency[v1.id]).to eq(is_latest: false, latest_available_version: 'V2R1', latest_available_id: v2.id)
    end
  end
end
