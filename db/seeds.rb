# frozen_string_literal: true

# rubocop:disable Rails/Output

# Populate the database for demonstration use.
unless Rails.env.development? || ENV.fetch('DISABLE_DATABASE_ENVIRONMENT_CHECK', false)
  raise 'This task is only for use in a development environment'
end

puts "Populating database for demo use:\n\n"

# --------------- #
# Seeds for Users #
# --------------- #
puts 'Creating Users...'
User.create(name: FFaker::Name.name, email: 'admin@example.com', password: '1234567ab!', admin: true)
users = []
10.times do
  name = FFaker::Name.name
  users << User.new(name: name, email: "#{name.split.join('.')}@example.com", password: '1234567ab!')
end
User.import(users)
User.all.each do |user|
  user.skip_confirmation!
  user.save!
end
puts 'Created Users'

# ------------------ #
# Seeds for Projects #
# ------------------ #
puts 'Creating Projects...'
photon3 = Project.create!(name: 'Photon 3')
photon4 = Project.create!(name: 'Photon 4')
vsphere = Project.create!(name: 'vSphere 7.0')
dummy_project = Project.create!(name: 'Nothing to See Here')
puts 'Created Projects'

# ------------------------- #
# Seeds for Project Members #
# ------------------------- #
puts 'Adding Users to Projects...'
project_members = []
User.all.each do |user|
  project_members << Membership.new(user: user, membership_id: photon3.id, membership_type: 'Project')
  project_members << Membership.new(user: user, membership_id: photon4.id, membership_type: 'Project')
  project_members << Membership.new(user: user, membership_id: vsphere.id, membership_type: 'Project')
end
Membership.import(project_members)
puts 'Project Members added'

# Counter cache update
Project.all.each { |p| Project.reset_counters(p.id, :memberships_count) }

# -------------- #
# Seeds for SRGs #
# -------------- #
puts 'Creating SRGs...'
srg_xml = File.read('./spec/fixtures/files/U_Web_Server_V2R3_Manual-xccdf.xml')
parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
web_srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
web_srg.xml = srg_xml
web_srg.save!

srg_xml = File.read('./spec/fixtures/files/U_GPOS_SRG_V2R1_Manual-xccdf.xml')
parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
gpos_srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
gpos_srg.xml = srg_xml
gpos_srg.save!
puts 'Created SRGs'

# ---------------------------- #
# Seeds for Project Components #
# ---------------------------- #
puts 'Creating Components...'
photon3_v1r1 = Component.create!(
  project: photon3,
  name: 'Photon OS 3',
  version: 1,
  release: 1,
  prefix: 'PHOS-03',
  based_on: gpos_srg
)
photon3_v1r1.reload
photon3_v1r1.rules.update(locked: true)
photon3_v1r1.update(released: true)

photon3_v1r1.duplicate(new_name: 'Photon OS 3', new_version: 1, new_release: 2).save!
photon3_v1r1.rules.update(locked: true)

photon4_v1r1 = Component.create!(
  project: photon4,
  name: 'Photon OS 4',
  version: 1,
  release: 1,
  prefix: 'PHOS-04',
  based_on: gpos_srg
)
photon4_v1r1.reload
photon4_v1r1.rules.update(locked: false)

photon3_v1r1_overlay = Component.create!(
  project: vsphere,
  component_id: photon3_v1r1.id,
  prefix: photon3_v1r1.prefix,
  security_requirements_guide_id: photon3_v1r1.security_requirements_guide_id,
  name: photon3_v1r1.name
)
photon3_v1r1_overlay.rules.update(locked: false)

vcenter_perf_v1r1 = Component.create!(
  project: vsphere,
  name: 'vCenter Perf',
  version: 1,
  release: 1,
  prefix: 'VCPF-01',
  based_on: web_srg
)
vcenter_perf_v1r1.rules.update(locked: false)

vcenter_sts_v1r1 = Component.create!(
  project: vsphere,
  name: 'vCenter STS',
  version: 1,
  release: 1,
  prefix: 'VSTS-01',
  based_on: web_srg
)
vcenter_sts_v1r1.rules.update(locked: false)

vcenter_vami_v1r1 = Component.create!(
  project: vsphere,
  name: 'vCenter VAMI',
  version: 1,
  release: 1,
  prefix: 'VAMI-01',
  based_on: web_srg
)
vcenter_vami_v1r1.rules.update(locked: false)

# Make a bunch of dummy released components
20.times do |n|
  name = SecureRandom.hex(3)
  c = Component.create(
    name: name,
    version: rand(1..9),
    release: rand(1..99),
    title: "#{name} STIG Readiness Guide",
    description: rand < 0.5 ? "Test description #{n + 1}" : nil,
    prefix: 'zzzz-00',
    based_on: web_srg,
    project: dummy_project
  )
  c.update(released: rand < 0.7)
  c.rules.order('RANDOM()').limit(c.rules.size * rand(25..35) / 100)
   .update(status: 'Applicable - Configurable')

  rule_satisfactions = []
  rules_with_duplicates_ids = c.rules.order('RANDOM()').limit(c.rules.size * rand(5..10) / 100).pluck(:id)
  c.rules.where.not(id: rules_with_duplicates_ids).order('RANDOM()')
   .limit(c.rules.size * rand(10..15) / 100).pluck(:id).each do |rule_id|
    rule_satisfactions << RuleSatisfaction.new(
      rule_id: rule_id,
      satisfied_by_rule_id: rules_with_duplicates_ids.sample
    )
  end
  RuleSatisfaction.import! rule_satisfactions

  # Call update last to trigger callbacks
  c.rules.update(locked: true, rule_weight: '10.0', rule_severity: RuleConstants::SEVERITIES.sample)
end
puts 'Created Components'

# rubocop:enable Rails/Output
