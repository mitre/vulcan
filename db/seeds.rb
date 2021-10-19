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
photon3_v1r1 = Component.create!(project: photon3, version: 'Photon OS 3 V1R1', prefix: 'PHOS-03', based_on: gpos_srg)
photon3_v1r1.reload
photon3_v1r1.rules.update(locked: true)
photon3_v1r1.update(released: true)
photon3_v1r1.duplicate(new_version: 'Photon OS 3 V1R2').save!
photon4_v1r1 = Component.create!(project: photon4, version: 'Photon OS 3 V1R1', prefix: 'PHOS-04', based_on: gpos_srg)
photon4_v1r1.reload
_photon3_v1r1_overlay = Component.create!(
  project: vsphere,
  component_id: photon3_v1r1.id,
  prefix: photon3_v1r1.prefix,
  security_requirements_guide_id: photon3_v1r1.security_requirements_guide_id,
  version: photon3_v1r1.version
)
_vcenter_perf_v1r1 = Component.create!(
  project: vsphere,
  version: 'vCenter Perf V1R1',
  prefix: 'VCPF-01',
  based_on: web_srg
)
_vcenter_sts_v1r1 = Component.create!(
  project: vsphere,
  version: 'vCenter STS V1R1',
  prefix: 'VSTS-01',
  based_on: web_srg
)
_vcenter_vami_v1r1 = Component.create!(
  project: vsphere,
  version: 'vCenter VAMI V1R1',
  prefix: 'VAMI-01',
  based_on: web_srg
)
# Make a bunch of dummy released components
20.times do
  c = Component.create(version: SecureRandom.hex(3), prefix: 'zzzz-00', based_on: web_srg, project: dummy_project)
  # rubocop:disable Rails/SkipsModelValidations
  c.rules.update_all(locked: true)
  # rubocop:enable Rails/SkipsModelValidations
  c.update(released: true)
end
puts 'Created Components'

# rubocop:enable Rails/Output
