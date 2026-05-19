# frozen_string_literal: true

# rubocop:disable Rails/Output, Rails/SkipsModelValidations
puts 'Creating Components...'

photon3 = Project.find_by!(name: 'Photon 3')
photon4 = Project.find_by!(name: 'Photon 4')
vsphere = Project.find_by!(name: 'vSphere 7.0')
container_platform = Project.find_by!(name: 'Container Platform')
dummy_project = Project.find_by!(name: 'Nothing to See Here')

gpos_srg = SecurityRequirementsGuide.find_by('name ILIKE ?', '%general purpose%')
web_srg = SecurityRequirementsGuide.find_by('name ILIKE ?', '%web server%')
container_srg = SecurityRequirementsGuide.find_by('name ILIKE ?', '%container%')

# ── Named components ──

photon3_v1r1 = SeedHelpers.seed_component(
  project: photon3, name: 'Photon OS 3', title: 'Photon OS 3 STIG Readiness Guide',
  prefix: 'PHOS-03', based_on: gpos_srg, version: 1, release: 1,
  admin_name: 'Photon OS Maintainer', admin_email: 'photon-team@example.com'
)
photon3_v1r1.reload
photon3_v1r1.rules.update_all(locked: true)
photon3_v1r1.update(released: true) unless photon3_v1r1.released?

unless Component.exists?(project: photon3, name: 'Photon OS 3', version: 1, release: 2)
  dup = photon3_v1r1.duplicate(new_name: 'Photon OS 3', new_version: 1, new_release: 2)
  dup.title = 'Photon OS 3 STIG Readiness Guide'
  dup.save!
  dup.rules.update_all(locked: true)
end

SeedHelpers.seed_component(
  project: photon4, name: 'Photon OS 4', title: 'Photon OS 4 STIG Readiness Guide',
  prefix: 'PHOS-04', based_on: gpos_srg,
  admin_name: 'Photon OS Maintainer', admin_email: 'photon-team@example.com'
).tap do |c|
  c.reload
  c.rules.update_all(locked: false)
end

photon3_v1r1_overlay = SeedHelpers.seed_component(
  project: vsphere, name: photon3_v1r1.name, title: 'Photon OS 3 Overlay for vSphere',
  prefix: photon3_v1r1.prefix, based_on: photon3_v1r1.based_on,
  component_id: photon3_v1r1.id,
  admin_name: 'vSphere Maintainer', admin_email: 'vsphere-team@example.com'
)
if photon3_v1r1_overlay.rules.empty?
  photon3_v1r1.rules.each do |orig_rule|
    photon3_v1r1_overlay.rules.create!(orig_rule.attributes.except('id', 'created_at', 'updated_at', 'component_id'))
  end
end
photon3_v1r1_overlay.rules.update_all(locked: false)

SeedHelpers.seed_component(
  project: vsphere, name: 'vCenter Perf', title: 'vCenter Performance Service STIG Readiness Guide',
  prefix: 'VCPF-01', based_on: web_srg,
  admin_name: 'vCenter Maintainer', admin_email: 'vcenter-team@example.com'
).rules.update_all(locked: false)

SeedHelpers.seed_component(
  project: vsphere, name: 'vCenter STS', title: 'vCenter STS Service STIG Readiness Guide',
  prefix: 'VSTS-01', based_on: web_srg,
  admin_name: 'vCenter Maintainer', admin_email: 'vcenter-team@example.com'
).rules.update_all(locked: false)

SeedHelpers.seed_component(
  project: vsphere, name: 'vCenter VAMI', title: 'vCenter VAMI Service STIG Readiness Guide',
  prefix: 'VAMI-01', based_on: web_srg,
  admin_name: 'vCenter Maintainer', admin_email: 'vcenter-team@example.com'
).rules.update_all(locked: false)

# ── Container Platform (active comment period) ──
if container_srg
  SeedHelpers.seed_component(
    project: container_platform, name: 'Container Platform', title: 'Container Platform STIG Readiness Guide',
    prefix: 'CNTR-01', based_on: container_srg,
    admin_name: 'Container Platform Maintainer', admin_email: 'platform-team@example.com',
    comment_phase: 'open',
    comment_period_starts_at: 1.day.ago,
    comment_period_ends_at: 14.days.from_now
  ).rules.update_all(locked: false)
end

# ── Dummy filler components ("Nothing to See Here") ──
# Purpose: stress-test the project list and component views with many records.
# Uses random hex names + varied released/unreleased states + rule satisfaction links.
# TODO: Consider replacing with a dedicated stress-test rake task (dev:stress)
#       that can create N components on demand without polluting the demo seed data.
needed = 20 - dummy_project.components.count
if needed.positive?
  puts "  Creating #{needed} dummy components..."
  needed.times do |n|
    name = SecureRandom.hex(3)
    c = Component.create(
      name: name,
      version: rand(1..9),
      release: rand(1..99),
      title: "#{name} STIG Readiness Guide",
      description: rand < 0.5 ? "Test description #{n + 1}" : nil,
      prefix: 'zzzz-00',
      based_on: web_srg,
      project: dummy_project,
      admin_name: 'QA Test Maintainer',
      admin_email: 'qa-team@example.com'
    )
    next unless c.persisted?

    c.update(released: rand < 0.7)
    c.rules.order('RANDOM()').limit(c.rules.size * rand(25..35) / 100)
     .update_all(status: 'Applicable - Configurable')

    rule_selection = c.rules.where(status: 'Applicable - Configurable')
    if rule_selection.any?
      c.rules.where.not(status: 'Applicable - Configurable').limit(3).each do |rule|
        satisfying_rule = rule_selection.sample
        rule.satisfied_by << satisfying_rule if satisfying_rule && rule.satisfied_by.exclude?(satisfying_rule)
        rule.save
      end
    end

    c.rules.update_all(locked: true, rule_weight: '10.0', rule_severity: RuleConstants::SEVERITIES.sample)
  end
end

# ── PoC backfill for legacy components ──
backfilled = Component.where(admin_name: [nil, '']).count
if backfilled.positive?
  puts "  Backfilling PoC on #{backfilled} legacy components..."
  Component.where(admin_name: [nil, '']).find_each do |c|
    matched = SeedHelpers::COMPONENT_POC_PATTERNS.find { |pattern, _| c.name =~ pattern }
    attrs = matched ? matched[1] : SeedHelpers::GENERIC_POC
    c.update_columns(attrs)
  end
  puts '  PoC backfill complete'
end

puts "  #{Component.count} components total"
# rubocop:enable Rails/Output, Rails/SkipsModelValidations
