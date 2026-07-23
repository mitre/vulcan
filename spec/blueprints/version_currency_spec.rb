# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Version currency Blueprint fields' do
  # Two releases of ONE SRG — real DISA shape: the XCCDF benchmark id
  # (srg_id) is identical across releases; only the version moves. A
  # release may reword the TITLE without a formal rename, so the newer
  # release carries a reworded title — the SRG's identity holds by id.
  let_it_be(:srg_old) do
    SecurityRequirementsGuide.insert_all([{
                                           srg_id: 'Currency_SRG', title: 'Currency Test SRG', version: 'V1R1',
                                           xml: '<xml/>', created_at: Time.current, updated_at: Time.current
                                         }])
    SecurityRequirementsGuide.find_by!(srg_id: 'Currency_SRG', version: 'V1R1')
  end

  let_it_be(:srg_latest) do
    SecurityRequirementsGuide.insert_all([{
                                           srg_id: 'Currency_SRG', title: 'Currency Test Security Requirements Guide',
                                           version: 'V2R3',
                                           xml: '<xml/>', created_at: Time.current, updated_at: Time.current
                                         }])
    SecurityRequirementsGuide.find_by!(srg_id: 'Currency_SRG', version: 'V2R3')
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

    it 'has null latest_available fields for a single-release SRG' do
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
      # Same benchmark id, newer version — real DISA release shape.
      SecurityRequirementsGuide.insert_all([{
                                             srg_id: real_srg.srg_id,
                                             title: real_srg.title, version: 'V99R1',
                                             xml: '<xml/>', created_at: Time.current, updated_at: Time.current
                                           }])
      SecurityRequirementsGuide.find_by!(version: 'V99R1', srg_id: real_srg.srg_id)
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

  # Currency is a correctness property of the WHOLE parent set: a
  # dual-lineage component is stale when ANY declared parent has a newer
  # release, and the latest_* fields point at the first stale parent
  # (primary first) so the update affordance has an actionable target.
  describe 'ComponentBlueprint :editor — multi-parent currency' do
    let_it_be(:fam_c_v1) do
      create(:security_requirements_guide, :skip_rules, srg_id: 'SRG-CUR-C', version: 'V1R1')
    end
    let_it_be(:fam_c_v2) do
      create(:security_requirements_guide, :skip_rules, srg_id: 'SRG-CUR-C', version: 'V1R2')
    end
    let_it_be(:fam_d_v1) do
      create(:security_requirements_guide, :skip_rules, srg_id: 'SRG-CUR-D', version: 'V1R1')
    end
    let_it_be(:fam_d_v2) do
      create(:security_requirements_guide, :skip_rules, srg_id: 'SRG-CUR-D', version: 'V1R2')
    end

    def dual_parent_component(primary:, secondary:)
      component = create(:component, :skip_rules, based_on: primary, prefix: 'CURM-00')
      component.component_source_srgs.create!(security_requirements_guide: secondary)
      component
    end

    it 'reports srg_is_latest=false when only the SECONDARY parent has a newer version' do
      component = dual_parent_component(primary: fam_c_v2, secondary: fam_d_v1)
      json = ComponentBlueprint.render_as_json(component, view: :editor)
      expect(json['srg_is_latest']).to be false
    end

    it 'points latest_version and latest_id at the stale secondary parent latest release' do
      component = dual_parent_component(primary: fam_c_v2, secondary: fam_d_v1)
      json = ComponentBlueprint.render_as_json(component, view: :editor)
      expect(json['srg_latest_version']).to eq('V1R2')
      expect(json['srg_latest_id']).to eq(fam_d_v2.id)
    end

    it 'reports srg_is_latest=true with null latest fields when every parent is current' do
      component = dual_parent_component(primary: fam_c_v2, secondary: fam_d_v2)
      json = ComponentBlueprint.render_as_json(component, view: :editor)
      expect(json['srg_is_latest']).to be true
      expect(json['srg_latest_version']).to be_nil
      expect(json['srg_latest_id']).to be_nil
    end

    it 'prefers the stale PRIMARY parent for the latest fields when both are stale' do
      component = dual_parent_component(primary: fam_c_v1, secondary: fam_d_v1)
      json = ComponentBlueprint.render_as_json(component, view: :editor)
      expect(json['srg_is_latest']).to be false
      expect(json['srg_latest_version']).to eq('V1R2')
      expect(json['srg_latest_id']).to eq(fam_c_v2.id)
    end
  end

  describe 'SecurityRequirementsGuide.srg_info_for_components — multi-parent' do
    let_it_be(:fam_e_v1) do
      create(:security_requirements_guide, :skip_rules, srg_id: 'SRG-CUR-E', version: 'V1R1')
    end
    let_it_be(:fam_f_v1) do
      create(:security_requirements_guide, :skip_rules, srg_id: 'SRG-CUR-F', version: 'V1R1')
    end
    let_it_be(:fam_f_v2) do
      create(:security_requirements_guide, :skip_rules, srg_id: 'SRG-CUR-F', version: 'V1R2')
    end

    it 'reports is_latest=false for a component whose secondary parent is stale, keeping primary display' do
      component = create(:component, :skip_rules, based_on: fam_e_v1, prefix: 'CURN-00')
      component.component_source_srgs.create!(security_requirements_guide: fam_f_v1)
      info = SecurityRequirementsGuide.srg_info_for_components([component])
      expect(info[component.id][:is_latest]).to be false
      expect(info[component.id][:version]).to eq('V1R1')
      expect(info[component.id][:title]).to eq(fam_e_v1.title)
    end

    it 'reports is_latest=true when all parents are current' do
      component = create(:component, :skip_rules, based_on: fam_e_v1, prefix: 'CURO-00')
      component.component_source_srgs.create!(security_requirements_guide: fam_f_v2)
      info = SecurityRequirementsGuide.srg_info_for_components([component])
      expect(info[component.id][:is_latest]).to be true
    end
  end
end
