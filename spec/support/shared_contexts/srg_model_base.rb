# frozen_string_literal: true

# Shared setup for model specs needing SRG + project + component + users.
# Provides SRG, project, users, component, rule, and memberships via let_it_be.
# Each split file includes this context.
RSpec.shared_context 'srg model base setup' do
  let_it_be(:srg) do
    srg_xml = Rails.root.join('db/seeds/srgs/U_Web_Server_SRG_V4R4_Manual-xccdf.xml').read
    parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    srg.xml = srg_xml
    srg.save!
    srg
  end
  let_it_be(:project) { create(:project, name: 'P1') }
  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:p_admin) { create(:user) }
  let_it_be(:p_reviewer) { create(:user) }
  let_it_be(:p_author) { create(:user) }
  let_it_be(:p_viewer) { create(:user) }
  let_it_be(:other_project) { create(:project, name: 'P2') }
  let_it_be(:other_p_admin) { create(:user) }
  let_it_be(:component) do
    Component.create!(project: project, name: 'Photon OS 3', title: 'Photon OS 3 STIG',
                      version: 'Photon OS 3 V1R1', prefix: 'PHOS-03', based_on: srg)
  end
  let_it_be(:rule) do
    Rule.create!(component: component, rule_id: 'P1-R1', status: 'Applicable - Configurable',
                 rule_severity: 'medium', srg_rule: srg.srg_rules.first)
  end

  before do
    Membership.create!(user: p_admin, membership: project, role: 'admin')
    Membership.create!(user: p_reviewer, membership: project, role: 'reviewer')
    Membership.create!(user: p_author, membership: project, role: 'author')
    Membership.create!(user: p_viewer, membership: project, role: 'viewer')
    Membership.create!(user: other_p_admin, membership: other_project, role: 'admin')
  end
end
