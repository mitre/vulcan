# frozen_string_literal: true

# Shared setup for all reviews MODEL specs (not request specs — see reviews_request_base.rb).
# Provides SRG, project, users, component, rule, and memberships via let_it_be.
# Each split file includes this context.
RSpec.shared_context 'reviews model base setup' do
  let_it_be(:reviews_srg) do
    srg_xml = Rails.root.join('db/seeds/srgs/U_Web_Server_SRG_V4R4_Manual-xccdf.xml').read
    parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    srg.xml = srg_xml
    srg.save!
    srg
  end
  let_it_be(:reviews_project) { create(:project, name: 'P1') }
  let_it_be(:reviews_admin) { create(:user, admin: true) }
  let_it_be(:reviews_p_admin) { create(:user) }
  let_it_be(:reviews_p_reviewer) { create(:user) }
  let_it_be(:reviews_p_author) { create(:user) }
  let_it_be(:reviews_p_viewer) { create(:user) }
  let_it_be(:reviews_other_project) { create(:project, name: 'P2') }
  let_it_be(:reviews_other_p_admin) { create(:user) }
  let_it_be(:reviews_component) do
    Component.create!(project: reviews_project, name: 'Photon OS 3', title: 'Photon OS 3 STIG',
                      version: 'Photon OS 3 V1R1', prefix: 'PHOS-03', based_on: reviews_srg)
  end
  let_it_be(:reviews_rule) do
    Rule.create!(component: reviews_component, rule_id: 'P1-R1', status: 'Applicable - Configurable',
                 rule_severity: 'medium', srg_rule: reviews_srg.srg_rules.first)
  end

  before do
    Membership.create!(user: reviews_p_admin, membership: reviews_project, role: 'admin')
    Membership.create!(user: reviews_p_reviewer, membership: reviews_project, role: 'reviewer')
    Membership.create!(user: reviews_p_author, membership: reviews_project, role: 'author')
    Membership.create!(user: reviews_p_viewer, membership: reviews_project, role: 'viewer')
    Membership.create!(user: reviews_other_p_admin, membership: reviews_other_project, role: 'admin')
  end
end
