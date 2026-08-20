# frozen_string_literal: true

# Shared setup for all component model specs.
# Creates SRG, project, and component ONCE. Each example gets a savepoint
# that rollbacks any mutations (update_columns, rule locks, etc.).
# This eliminates ~50 SRG parses + ~50 component rule imports.
RSpec.shared_context 'components model base setup' do
  let_it_be(:components_srg) do
    srg_xml = Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read
    parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    srg.xml = srg_xml
    srg.save!
    srg
  end
  # Core SRG for srg-kind components (parent eligibility requires
  # core parents for that kind; components_srg is derived and serves the
  # stig-kind components).
  let_it_be(:components_core_srg) do
    create(:security_requirements_guide, :skip_rules, :core,
           srg_id: 'SRG-CORE-TEST', version: 'V1R1')
  end
  let_it_be(:components_project) { create(:project, name: 'Photon OS 3') }
  let_it_be(:components_component) do
    Component.create!(project: components_project, name: 'Photon OS 3', title: 'Photon OS 3 STIG',
                      version: 'Photon OS 3 V1R1', prefix: 'PHOS-03', based_on: components_srg)
  end
end
