# frozen_string_literal: true

# rubocop:disable Rails/Output

# Populate the database for demonstration/evaluation use.
#
# IDEMPOTENT: Safe to run multiple times — uses find_or_create_by patterns.
# See: https://thoughtbot.com/blog/seeds-of-destruction
#
# Environments:
#   - development/test: always seeds (existing behavior)
#   - production: only seeds when VULCAN_SEED_DEMO_DATA=true
#
# Usage:
#   VULCAN_SEED_DEMO_DATA=true docker compose up   # demo instance with sample data
#   docker compose up                                # clean production (no demo data)
#
unless Rails.env.local? || ENV['VULCAN_SEED_DEMO_DATA'] == 'true'
  puts 'Skipping seed data (set VULCAN_SEED_DEMO_DATA=true to populate demo data)'
  return
end

# DoD-compliant demo password: 16 chars, 2+ uppercase, 2+ lowercase, 2+ digits, 2+ special
DEMO_PASSWORD = '12qwaszx!@QWASZX'

# Create demo admin only if no admin exists yet (admin:bootstrap may have already created one)
unless User.exists?(admin: true)
  puts 'Creating demo admin (admin@example.com)...'
  admin = User.new(name: 'Demo Admin', email: 'admin@example.com', password: DEMO_PASSWORD, admin: true)
  admin.skip_confirmation!
  admin.save!
  puts "  Demo admin created (password: #{DEMO_PASSWORD})"
end

puts "Populating database for demo use:\n\n"

# Helper to load an XCCDF XML file and create the corresponding model record.
# Idempotent: skips if a record with the same srg_id/stig_id already exists.
def seed_xccdf(filepath)
  xml = File.read(filepath)
  parsed = Xccdf::Benchmark.parse(xml)
  title = parsed.try(:title)&.first&.downcase || ''

  is_srg = title.include?('requirements guide') || filepath.to_s.include?('/srgs/')
  is_stig = title.include?('implementation guide') || title.include?('stig') || filepath.to_s.include?('/stigs/')

  if is_srg
    record = SecurityRequirementsGuide.from_mapping(parsed)
    existing = SecurityRequirementsGuide.find_by(srg_id: record.srg_id)
    if existing
      puts "  Already exists: #{existing.name} (SecurityRequirementsGuide)"
      return existing
    end
    record.xml = xml
  elsif is_stig
    record = Stig.from_mapping(parsed)
    existing = Stig.find_by(stig_id: record.stig_id)
    if existing
      puts "  Already exists: #{existing.name} (Stig)"
      return existing
    end
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
if User.count < 5
  users = []
  10.times do
    name = FFaker::Name.name
    users << User.new(name: name, email: "#{name.split.join('.')}@example.com", password: DEMO_PASSWORD)
  end
  User.import(users)
  User.find_each do |user|
    user.skip_confirmation!
    user.save!
  end
  puts 'Created Users'
else
  puts 'Users already exist, skipping'
end

# ------------------ #
# Seeds for Projects #
# ------------------ #
puts 'Creating Projects...'
photon3 = Project.find_or_create_by!(name: 'Photon 3')
photon4 = Project.find_or_create_by!(name: 'Photon 4')
vsphere = Project.find_or_create_by!(name: 'vSphere 7.0')
container_platform = Project.find_or_create_by!(name: 'Container Platform')
dummy_project = Project.find_or_create_by!(name: 'Nothing to See Here')
puts 'Created Projects'

# ------------------------- #
# Seeds for Project Members #
# ------------------------- #
puts 'Adding Users to Projects...'
[photon3, photon4, vsphere, container_platform].each do |project|
  User.find_each do |user|
    Membership.find_or_create_by!(user: user, membership_id: project.id, membership_type: 'Project')
  end
end
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

# ---------------------------------------------------------------- #
# Helper: find or create a component with all required attributes  #
# ---------------------------------------------------------------- #
def seed_component(project:, name:, title:, prefix:, based_on:, version: 1, release: 1, **attrs)
  raise "seed_component: based_on (SRG) is nil for '#{name}' — check SRG seed files" unless based_on

  c = Component.find_or_initialize_by(project: project, name: name, version: version, release: release)
  c.title = title
  c.prefix = prefix
  c.based_on = based_on
  attrs.each { |k, v| c.send(:"#{k}=", v) }
  c.save!
  c
end

# ---------------------------- #
# Seeds for Project Components #
# ---------------------------- #
puts 'Creating Components...'

photon3_v1r1 = seed_component(
  project: photon3, name: 'Photon OS 3', title: 'Photon OS 3 STIG Readiness Guide',
  prefix: 'PHOS-03', based_on: gpos_srg, version: 1, release: 1
)
photon3_v1r1.reload
photon3_v1r1.rules.update(locked: true)
photon3_v1r1.update(released: true)

unless Component.exists?(project: photon3, name: 'Photon OS 3', version: 1, release: 2)
  dup = photon3_v1r1.duplicate(new_name: 'Photon OS 3', new_version: 1, new_release: 2)
  dup.title = 'Photon OS 3 STIG Readiness Guide'
  dup.save!
  dup.rules.update(locked: true)
end

photon4_v1r1 = seed_component(
  project: photon4, name: 'Photon OS 4', title: 'Photon OS 4 STIG Readiness Guide',
  prefix: 'PHOS-04', based_on: gpos_srg
)
photon4_v1r1.reload
photon4_v1r1.rules.update(locked: false)

photon3_v1r1_overlay = seed_component(
  project: vsphere, name: photon3_v1r1.name, title: 'Photon OS 3 Overlay for vSphere',
  prefix: photon3_v1r1.prefix, based_on: photon3_v1r1.based_on,
  component_id: photon3_v1r1.id
)
# Overlay components need rules duplicated from the parent component
if photon3_v1r1_overlay.rules.empty?
  photon3_v1r1.rules.each do |orig_rule|
    photon3_v1r1_overlay.rules.create!(orig_rule.attributes.except('id', 'created_at', 'updated_at', 'component_id'))
  end
end
photon3_v1r1_overlay.rules.update(locked: false)

seed_component(
  project: vsphere, name: 'vCenter Perf', title: 'vCenter Performance Service STIG Readiness Guide',
  prefix: 'VCPF-01', based_on: web_srg
).rules.update(locked: false)

seed_component(
  project: vsphere, name: 'vCenter STS', title: 'vCenter STS Service STIG Readiness Guide',
  prefix: 'VSTS-01', based_on: web_srg
).rules.update(locked: false)

seed_component(
  project: vsphere, name: 'vCenter VAMI', title: 'vCenter VAMI Service STIG Readiness Guide',
  prefix: 'VAMI-01', based_on: web_srg
).rules.update(locked: false)

# Container Platform project (uses Container Platform SRG)
container_srg = srg_records[:container]
if container_srg
  seed_component(
    project: container_platform, name: 'Container Platform', title: 'Container Platform STIG Readiness Guide',
    prefix: 'CNTR-01', based_on: container_srg
  ).rules.update(locked: false)
end

# Make a bunch of dummy released components for "Nothing to See Here"
if dummy_project.components.count < 20
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
    next unless c.persisted?

    c.update(released: rand < 0.7)
    c.rules.order('RANDOM()').limit(c.rules.size * rand(25..35) / 100)
     .update(status: 'Applicable - Configurable')

    # Add Rule satisfaction
    rule_selection = c.rules.where(status: 'Applicable - Configurable')
    if rule_selection.any?
      c.rules.where.not(status: 'Applicable - Configurable').limit(3).each do |rule|
        satisfying_rule = rule_selection.sample
        rule.satisfied_by << satisfying_rule if satisfying_rule && rule.satisfied_by.exclude?(satisfying_rule)
        rule.save
      end
    end

    c.rules.update(locked: true, rule_weight: '10.0', rule_severity: RuleConstants::SEVERITIES.sample)
  end
end
puts 'Created Components'

# rubocop:enable Rails/Output
