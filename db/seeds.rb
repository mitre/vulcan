# frozen_string_literal: true

# rubocop:disable Rails/Output

# Populate the database for demonstration use.
raise 'This task is only for use in a development environment' unless Rails.env.development? || ENV.fetch('DISABLE_DATABASE_ENVIRONMENT_CHECK', false)

puts "Populating database for demo use:\n\n"

# Helper to load an XCCDF XML file and create the corresponding model record.
# Works for both SecurityRequirementsGuide and Stig — the after_create callback
# on each model automatically imports the child rules.
#
# Classification uses the title first (keywords like "Requirements Guide" or
# "Implementation Guide"), then falls back to the seed directory path.
def seed_xccdf(filepath)
  xml = File.read(filepath)
  parsed = Xccdf::Benchmark.parse(xml)
  title = parsed.try(:title)&.first&.downcase || ''

  is_srg = title.include?('requirements guide') || filepath.to_s.include?('/srgs/')
  is_stig = title.include?('implementation guide') || title.include?('stig') || filepath.to_s.include?('/stigs/')

  if is_srg
    record = SecurityRequirementsGuide.from_mapping(parsed)
    record.xml = xml
  elsif is_stig
    record = Stig.from_mapping(parsed)
    record.xml = Nokogiri::XML(xml)
  else
    puts "  Skipping #{File.basename(filepath)} (unrecognized benchmark type)"
    return nil
  end

  record.save!
  puts "  Loaded #{record.name} (#{record.class.name})"
  record
end

# --------------- #
# Seeds for Users #
# --------------- #
puts 'Creating Users...'
User.create(name: FFaker::Name.name, email: 'admin@example.com', password: '1qaz!QAZ1qaz!QAZ', admin: true)
users = []
10.times do
  name = FFaker::Name.name
  users << User.new(name: name, email: "#{name.split.join('.')}@example.com", password: '1qaz!QAZ1qaz!QAZ')
end
User.import(users)
User.find_each do |user|
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
container_platform = Project.create!(name: 'Container Platform')
dummy_project = Project.create!(name: 'Nothing to See Here')
puts 'Created Projects'

# ------------------------- #
# Seeds for Project Members #
# ------------------------- #
puts 'Adding Users to Projects...'
project_members = []
User.find_each do |user|
  project_members << Membership.new(user: user, membership_id: photon3.id, membership_type: 'Project')
  project_members << Membership.new(user: user, membership_id: photon4.id, membership_type: 'Project')
  project_members << Membership.new(user: user, membership_id: vsphere.id, membership_type: 'Project')
  project_members << Membership.new(user: user, membership_id: container_platform.id, membership_type: 'Project')
end
Membership.import(project_members)
puts 'Project Members added'

# Counter cache update
Project.find_each { |p| Project.reset_counters(p.id, :memberships_count) }

# -------------- #
# Seeds for SRGs #
# -------------- #
puts 'Creating SRGs...'
srg_dir = Rails.root.join('db/seeds/srgs')
srg_records = {}
Dir.glob(srg_dir.join('*.xml')).each do |filepath|
  record = seed_xccdf(filepath)
  next unless record

  # Track by short name for component creation below
  basename = File.basename(filepath)
  srg_records[:gpos] = record if basename.include?('GPOS')
  srg_records[:web_server] = record if basename.include?('Web_Server')
  srg_records[:container] = record if basename.include?('Container')
  srg_records[:database] = record if basename.include?('Database')
end
gpos_srg = srg_records[:gpos]
web_srg = srg_records[:web_server]
puts "Created #{SecurityRequirementsGuide.count} SRGs"

# --------------- #
# Seeds for STIGs #
# --------------- #
puts 'Creating STIGs...'
stig_dir = Rails.root.join('db/seeds/stigs')
Dir.glob(stig_dir.join('*.xml')).each do |filepath|
  seed_xccdf(filepath)
end
puts "Created #{Stig.count} STIGs"

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
# Overlay components need to have rules duplicated from the parent component
photon3_v1r1.rules.each do |orig_rule|
  photon3_v1r1_overlay.rules.create!(orig_rule.attributes.except('id', 'created_at', 'updated_at', 'component_id'))
end
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

# Container Platform project (uses Container Platform SRG)
container_srg = srg_records[:container]
if container_srg
  container_v1r1 = Component.create!(
    project: container_platform,
    name: 'Container Platform',
    version: 1,
    release: 1,
    prefix: 'CNTR-01',
    based_on: container_srg
  )
  container_v1r1.rules.update(locked: false)
end

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

  # Add Rule satisfaction:
  # Only Applicable - Configurable rule can satisfy other rules
  rule_selection = c.rules.where(status: 'Applicable - Configurable')
  if rule_selection.any?
    c.rules.where.not(status: 'Applicable - Configurable').limit(3).each do |rule|
      satisfying_rule = rule_selection.sample
      rule.satisfied_by << satisfying_rule if satisfying_rule
      # Save the rule to trigger callbacks
      rule.save
    end
  end

  # Call update last to trigger callbacks
  c.rules.update(locked: true, rule_weight: '10.0', rule_severity: RuleConstants::SEVERITIES.sample)
end
puts 'Created Components'

# rubocop:enable Rails/Output
