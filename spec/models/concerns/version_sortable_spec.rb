# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VersionSortable do
  # Test via SecurityRequirementsGuide which includes the concern.
  # Use insert_all to skip after_create :import_srg_rules (needs real XCCDF XML).
  let_it_be(:srg_v2r1) do
    SecurityRequirementsGuide.insert_all([{
                                           srg_id: 'Test_SRG', title: 'Test SRG', version: 'V2R1',
                                           xml: '<xml/>', created_at: Time.current, updated_at: Time.current
                                         }])
    SecurityRequirementsGuide.find_by!(srg_id: 'Test_SRG', version: 'V2R1')
  end
  let_it_be(:srg_v3r3) do
    SecurityRequirementsGuide.insert_all([{
                                           srg_id: 'Test_SRG_V3', title: 'Test SRG', version: 'V3R3',
                                           xml: '<xml/>', created_at: Time.current, updated_at: Time.current
                                         }])
    SecurityRequirementsGuide.find_by!(srg_id: 'Test_SRG_V3', version: 'V3R3')
  end
  let_it_be(:other_srg) do
    SecurityRequirementsGuide.insert_all([{
                                           srg_id: 'Other_SRG', title: 'Other SRG', version: 'V1R1',
                                           xml: '<xml/>', created_at: Time.current, updated_at: Time.current
                                         }])
    SecurityRequirementsGuide.find_by!(srg_id: 'Other_SRG', version: 'V1R1')
  end

  describe '.latest_versions' do
    it 'returns only the highest version per family (by title)' do
      latest = SecurityRequirementsGuide.latest_versions
      latest_titles = latest.pluck(:title, :version).to_h

      expect(latest_titles['Test SRG']).to eq('V3R3')
      expect(latest_titles['Other SRG']).to eq('V1R1')
    end
  end

  describe '#latest?' do
    it 'returns true for the newest version in its family' do
      expect(srg_v3r3.latest?).to be true
    end

    it 'returns false for an older version in the same family' do
      expect(srg_v2r1.latest?).to be false
    end

    it 'returns true for a single-version family' do
      expect(other_srg.latest?).to be true
    end
  end

  describe '#latest_for_family' do
    it 'returns the latest record for the same family' do
      expect(srg_v2r1.latest_for_family).to eq(srg_v3r3)
    end

    it 'returns self when already the latest' do
      expect(srg_v3r3.latest_for_family).to eq(srg_v3r3)
    end

    it 'returns self for a single-version family' do
      expect(other_srg.latest_for_family).to eq(other_srg)
    end
  end
end
