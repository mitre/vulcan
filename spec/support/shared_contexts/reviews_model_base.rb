# frozen_string_literal: true

# Shared setup for all reviews MODEL specs (not request specs — see reviews_base.rb).
# Provides SRG, projects, users, component, rule, and memberships via instance vars.
# Each split file includes this context.
RSpec.shared_context 'reviews model base setup' do
  # Expensive setup: SRG parse + component creation — do once
  let_it_be(:shared_srg) do
    srg_xml = Rails.root.join('db/seeds/srgs/U_Web_Server_SRG_V4R4_Manual-xccdf.xml').read
    parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    srg.xml = srg_xml
    srg.save!
    srg
  end
  let_it_be(:shared_p1) { Project.create(name: 'P1') }
  let_it_be(:shared_p2) { Project.create(name: 'P2') }
  let_it_be(:shared_admin) { create(:user, admin: true) }
  let_it_be(:shared_p_admin) { create(:user) }
  let_it_be(:shared_p_reviewer) { create(:user) }
  let_it_be(:shared_p_author) { create(:user) }
  let_it_be(:shared_p_viewer) { create(:user) }
  let_it_be(:shared_other_p_admin) { create(:user) }
  let_it_be(:shared_component) do
    Component.create!(project: shared_p1, name: 'Photon OS 3', title: 'Photon OS 3 STIG',
                      version: 'Photon OS 3 V1R1', prefix: 'PHOS-03', based_on: shared_srg)
  end
  let_it_be(:shared_rule) do
    Rule.create(component: shared_component, rule_id: 'P1-R1', status: 'Applicable - Configurable',
                rule_severity: 'medium', srg_rule: shared_srg.srg_rules.first)
  end

  before do
    # Set up memberships per-example (rolled back by savepoint)
    Membership.create(user: shared_p_admin, membership: shared_p1, role: 'admin')
    Membership.create(user: shared_p_reviewer, membership: shared_p1, role: 'reviewer')
    Membership.create(user: shared_p_author, membership: shared_p1, role: 'author')
    Membership.create(user: shared_p_viewer, membership: shared_p1, role: 'viewer')
    Membership.create(user: shared_other_p_admin, membership: shared_p2, role: 'admin')
    # Expose via instance vars for existing test code
    @p1 = shared_p1
    @p2 = shared_p2
    @admin = shared_admin
    @p_admin = shared_p_admin
    @p_reviewer = shared_p_reviewer
    @p_author = shared_p_author
    @p_viewer = shared_p_viewer
    @other_p_admin = shared_other_p_admin
    @p1_c1 = shared_component
    @p1r1 = shared_rule
  end
end
