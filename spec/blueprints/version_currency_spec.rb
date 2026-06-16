# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Version currency Blueprint fields' do
  # Create two SRG versions in the same family + one in a different family.
  # Skip import_srg_rules callback (needs real XCCDF).
  let_it_be(:srg_old) do
    SecurityRequirementsGuide.insert_all([{
                                           srg_id: 'Currency_SRG', title: 'Currency Test SRG', version: 'V1R1',
                                           xml: '<xml/>', created_at: Time.current, updated_at: Time.current
                                         }])
    SecurityRequirementsGuide.find_by!(srg_id: 'Currency_SRG', version: 'V1R1')
  end

  let_it_be(:srg_latest) do
    SecurityRequirementsGuide.insert_all([{
                                           srg_id: 'Currency_SRG_V2', title: 'Currency Test SRG', version: 'V2R3',
                                           xml: '<xml/>', created_at: Time.current, updated_at: Time.current
                                         }])
    SecurityRequirementsGuide.find_by!(srg_id: 'Currency_SRG_V2', version: 'V2R3')
  end

  describe 'SrgBlueprint' do
    it 'includes is_latest=true for the newest version' do
      json = SrgBlueprint.render_as_json(srg_latest)
      expect(json['is_latest']).to be true
    end

    it 'includes is_latest=false for an older version' do
      json = SrgBlueprint.render_as_json(srg_old)
      expect(json['is_latest']).to be false
    end

    it 'includes latest_available_version when not latest' do
      json = SrgBlueprint.render_as_json(srg_old)
      expect(json['latest_available_version']).to eq('V2R3')
    end

    it 'includes latest_available_id when not latest' do
      json = SrgBlueprint.render_as_json(srg_old)
      expect(json['latest_available_id']).to eq(srg_latest.id)
    end

    it 'has null latest_available fields when is_latest=true' do
      json = SrgBlueprint.render_as_json(srg_latest)
      expect(json['latest_available_version']).to be_nil
      expect(json['latest_available_id']).to be_nil
    end
  end

  describe 'StigBlueprint' do
    let_it_be(:stig) do
      create(:stig)
    end

    it 'includes is_latest field' do
      json = StigBlueprint.render_as_json(stig)
      expect(json).to have_key('is_latest')
      expect(json['is_latest']).to be true
    end

    it 'has null latest_available fields for single-version family' do
      json = StigBlueprint.render_as_json(stig)
      expect(json['latest_available_version']).to be_nil
      expect(json['latest_available_id']).to be_nil
    end
  end

  describe 'ComponentBlueprint :editor' do
    let_it_be(:real_srg) do
      srg_xml = Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read
      parsed = Xccdf::Benchmark.parse(srg_xml)
      srg = SecurityRequirementsGuide.from_mapping(parsed)
      srg.xml = srg_xml
      srg.save!
      srg
    end
    let_it_be(:newer_gpos) do
      SecurityRequirementsGuide.insert_all([{
                                             srg_id: 'General_Purpose_Operating_System_V99',
                                             title: real_srg.title, version: 'V99R1',
                                             xml: '<xml/>', created_at: Time.current, updated_at: Time.current
                                           }])
      SecurityRequirementsGuide.find_by!(version: 'V99R1', title: real_srg.title)
    end
    let_it_be(:component) { create(:component, based_on: real_srg) }

    it 'includes srg_is_latest=false when a newer SRG version exists' do
      newer_gpos # ensure created
      json = ComponentBlueprint.render_as_json(component, view: :editor)
      expect(json['srg_is_latest']).to be false
    end

    it 'includes srg_latest_version pointing to the newer version' do
      json = ComponentBlueprint.render_as_json(component, view: :editor)
      expect(json['srg_latest_version']).to eq('V99R1')
    end

    it 'includes srg_latest_id for navigation to the newer SRG' do
      json = ComponentBlueprint.render_as_json(component, view: :editor)
      expect(json['srg_latest_id']).to eq(newer_gpos.id)
    end
  end
end
