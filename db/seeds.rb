# frozen_string_literal: true

# rubocop:disable Rails/Output

# Populate the database for demonstration use.
raise 'This task is only for use in a development environment' unless Rails.env.development? || ENV.fetch('DISABLE_DATABASE_ENVIRONMENT_CHECK', false)

# Check if database has already been seeded
# Seeds are meant to run once on a fresh database (Rails convention)
if User.exists?(email: 'admin@example.com')
  puts "\n✅ Database already contains seed data"
  puts ''
  puts 'To reset and reseed the database, use:'
  puts '  bin/rails db:reset'
  puts ''
  exit 0
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
dummy_project = Project.create!(name: 'Nothing to See Here')
container_project = Project.create!(name: 'Container Security Requirements Guide')
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
  project_members << Membership.new(user: user, membership_id: dummy_project.id, membership_type: 'Project')
  project_members << Membership.new(user: user, membership_id: container_project.id, membership_type: 'Project')
end
Membership.import(project_members)
puts 'Project Members added'

# Counter cache update
Project.find_each { |p| Project.reset_counters(p.id, :memberships_count) }

# -------------- #
# Seeds for SRGs #
# -------------- #
# SRG loading is optional - if files are present they'll be loaded,
# otherwise Vulcan starts with no SRGs (they can be imported via the UI)

def load_srg_from_file(file_path, description = nil)
  return nil unless File.exist?(file_path)

  puts "  Loading #{description || file_path}..."
  srg_xml = File.read(file_path)
  parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
  srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
  srg.xml = srg_xml
  srg.save!
  srg
rescue StandardError => e
  puts "  Warning: Failed to load #{file_path}: #{e.message}"
  nil
end

puts 'Loading SRGs (if available)...'

# Load SRGs from spec fixtures (used for demo/testing)
web_srg = load_srg_from_file('./spec/fixtures/files/U_Web_Server_V2R3_Manual-xccdf.xml', 'Web Server SRG')
gpos_srg = load_srg_from_file('./spec/fixtures/files/U_GPOS_SRG_V2R1_Manual-xccdf.xml', 'GPOS SRG')

# Load additional SRGs from project root (optional)
load_srg_from_file('./Application_Core_SRG_Core.xml', 'Application Core SRG')
load_srg_from_file('./Operating_System_Core_Core.xml', 'Operating System Core SRG')

srg_count = SecurityRequirementsGuide.count
if srg_count > 0
  puts "Loaded #{srg_count} SRG(s)"
else
  puts 'No SRG files found - Vulcan will start without SRGs'
  puts 'You can import SRGs later through the web interface'
end

# ---------------------------- #
# Seeds for Project Components #
# ---------------------------- #
# Components require SRGs to be based on - only create if SRGs were loaded
if gpos_srg || web_srg
  puts 'Creating Components...'

  if gpos_srg
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
  end

  if web_srg
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
  end

  puts 'Created Components'
else
  puts 'Skipping component creation (no SRGs available)'
  puts 'You can create components after importing SRGs through the web interface'
end

# rubocop:enable Rails/Output
