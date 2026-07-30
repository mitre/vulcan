# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: The core SRGs are DEFINED — exactly three, DISA-published:
# Operating System Core, Network Core, Application Core. Core-ness is
# RECOGNITION of those documents at creation, never a user designation.
# Recognition is one-directional: a matching benchmark id flags the record
# core; a non-matching id never unsets an explicitly-set core (scratch and
# walkthrough cores use arbitrary ids). The SRG-type creation picker's
# eligibility filter consumes the flag.
# ==========================================================================
RSpec.describe SecurityRequirementsGuide do
  describe 'CORE_SRG_IDS' do
    it 'holds exactly the three DISA core benchmark ids' do
      expect(described_class::CORE_SRG_IDS)
        .to contain_exactly('Operating_System_Core', 'Network_Core_SRG', 'Application_Core_SRG')
    end
  end

  describe 'recognition on create' do
    it 'flags the real Application core document as core through the import path' do
      xml = Rails.root.join('db/seeds/srgs/U_Application_Core_SRG_V4R1_Manual-xccdf.xml').read
      srg = described_class.from_mapping(Xccdf::Benchmark.parse(xml))
      srg.xml = xml
      srg.skip_rule_import = true
      srg.save!
      expect(srg.reload.core).to be true
    end

    it 'flags a record carrying the Network core benchmark id' do
      srg = create(:security_requirements_guide, :skip_rules,
                   srg_id: 'Network_Core_SRG', title: 'Network Core Security Requirements Guide')
      expect(srg.core).to be true
    end

    it 'flags a record carrying the Operating System core benchmark id' do
      srg = create(:security_requirements_guide, :skip_rules,
                   srg_id: 'Operating_System_Core', title: 'Operating System Core Security Requirements Guide')
      expect(srg.core).to be true
    end

    it 'does not flag a derived SRG' do
      srg = create(:security_requirements_guide, :skip_rules)
      expect(srg.core).to be false
    end

    it 'never unsets an explicitly-set core on a non-matching id' do
      srg = create(:security_requirements_guide, :skip_rules, :core)
      expect(srg.core).to be true
    end
  end
end
