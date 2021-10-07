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
puts 'Created Users'

# ------------------ #
# Seeds for Projects #
# ------------------ #
puts 'Creating Projects...'
photon3 = Project.create!(name: 'Photon 3')
photon4 = Project.create!(name: 'Photon 4')
vsphere = Project.create!(name: 'vSphere 7.0')
puts 'Created Projects'

# ------------------------- #
# Seeds for Project Members #
# ------------------------- #
puts 'Adding Users to Projects...'
project_members = []
User.all.each do |user|
  project_members << ProjectMember.new(user: user, project: photon3)
  project_members << ProjectMember.new(user: user, project: photon4)
  project_members << ProjectMember.new(user: user, project: vsphere)
end
ProjectMember.import(project_members)
puts 'Project Members added'

# Counter cache update
Project.all.each { |p| Project.reset_counters(p.id, :project_members) }

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
photon3_v1r1 = Component.create!(project: photon3, version: 'Photon OS 3 V1R1', prefix: 'PHOS-03', based_on: web_srg)
photon3_v1r1.from_mapping(web_srg)
photon3_v1r1.reload
photon4_v1r1 = Component.create!(project: photon4, version: 'Photon OS 3 V1R1', prefix: 'PHOS-04', based_on: web_srg)
photon4_v1r1.from_mapping(web_srg)
photon4_v1r1.reload
puts 'Created Components'

# rubocop:enable Rails/Output
