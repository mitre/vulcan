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

# Demo admin password from env var, with a default for local dev convenience.
# In deployed demo instances, set VULCAN_SEED_ADMIN_PASSWORD to override.
DEMO_PASSWORD = ENV.fetch('VULCAN_SEED_ADMIN_PASSWORD', '12qwaszx!@QWASZX')

# Create demo admin only if no admin exists yet (admin:bootstrap may have already created one)
unless User.exists?(admin: true)
  puts 'Creating demo admin (admin@example.com)...'
  admin = User.new(name: 'Demo Admin', email: 'admin@example.com', password: DEMO_PASSWORD, admin: true)
  admin.skip_confirmation!
  admin.save!
  puts "  Demo admin created (password from #{ENV.key?('VULCAN_SEED_ADMIN_PASSWORD') ? 'VULCAN_SEED_ADMIN_PASSWORD env var' : 'default'})"
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
def seed_component(**opts)
  project  = opts.fetch(:project)
  name     = opts.fetch(:name)
  title    = opts.fetch(:title)
  prefix   = opts.fetch(:prefix)
  based_on = opts.fetch(:based_on)
  version  = opts.fetch(:version, 1)
  release  = opts.fetch(:release, 1)

  raise ArgumentError, "seed_component: based_on (SRG) is nil for '#{name}' — check SRG seed files" unless based_on

  c = Component.find_or_initialize_by(project: project, name: name, version: version, release: release)
  c.title = title
  c.prefix = prefix
  c.based_on = based_on
  extra_keys = opts.keys - %i[project name title prefix based_on version release]
  extra_keys.each { |k| c.send(:"#{k}=", opts[k]) }
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

# ------------------------------------------------------------ #
# Seeds for public-comment-review demo (PR #717)               #
# ------------------------------------------------------------ #
# Seeds a small set of comments on the Container Platform component
# so the triage table, my-comments page, and section icons have
# something to render without manual setup.
#
# Idempotent: skips entirely if any 'comment' Reviews already exist.
puts 'Seeding demo comments for public-comment-review workflow...'

container_component = container_platform.components.find_by(name: 'Container Platform')

# Helper: any top-level comment Reviews exist on this project's components?
project_has_comments = lambda do |project|
  Review.where(action: 'comment', responding_to_review_id: nil)
        .joins(:rule)
        .merge(Rule.where(component: project.components))
        .exists?
end

if container_component.nil?
  puts '  No Container Platform component — skipping comment seeds'
else
  # Reuse two existing non-admin users as our viewer + author (or fall back to admin
  # if seed-user creation was somehow skipped).
  demo_admin = User.find_by(admin: true)
  non_admins = User.where(admin: [false, nil]).limit(2).to_a
  viewer_user = non_admins[0] || demo_admin
  author_user = non_admins[1] || demo_admin
  other_voice = User.where.not(id: [viewer_user&.id, author_user&.id, demo_admin&.id].compact)
                    .where(admin: [false, nil]).first || viewer_user

  if project_has_comments.call(container_platform)
    puts '  Container Platform comments already seeded, skipping that block'
  elsif container_component.rules.count < 4
    puts "  Not enough rules on Container Platform (#{container_component.rules.count}) — skipping comment seeds"
  else
    # Memberships — viewer-tier on the project for the commenter, author-tier for
    # the triager. find_or_create_by avoids duplicate-membership validator failures.
    Membership.find_or_create_by!(user: viewer_user, membership: container_platform) do |m|
      m.role = 'viewer'
    end
    Membership.find_or_create_by!(user: author_user, membership: container_platform) do |m|
      m.role = 'author'
    end
    Membership.find_or_create_by!(user: other_voice, membership: container_platform) do |m|
      m.role = 'viewer'
    end

    rules = container_component.rules.order(:rule_id).limit(6).to_a
    rule_a, rule_b, rule_c, rule_d = rules

    # 1) Pending comment, section-tagged to Check
    Review.create!(
      user: viewer_user, rule: rule_a, action: 'comment',
      comment: 'The check text mentions runc 1.0 but the SRG section requires runc >= 1.1.4. Should this be tightened?',
      section: 'check_content'
    )

    # 2) Pending comment, section-tagged to Fix (different rule, same author)
    Review.create!(
      user: viewer_user, rule: rule_b, action: 'comment',
      comment: 'The fix text could include the seccomp profile path more explicitly.',
      section: 'fixtext'
    )

    # 3) Pending general (un-sectioned) comment from a different user
    Review.create!(
      user: other_voice, rule: rule_c, action: 'comment',
      comment: 'Could we soften the severity from CAT II to CAT III for environments without external network access?',
      section: nil
    )

    # 4) Concur (accepted), with a triager response in the thread
    accepted = Review.create!(
      user: viewer_user, rule: rule_a, action: 'comment',
      comment: 'Vulnerability discussion paragraph 2 has a typo: "kuberenetes" should be "kubernetes".',
      section: 'vuln_discussion'
    )
    accepted.update!(triage_status: 'concur', triage_set_by_id: author_user.id, triage_set_at: 1.day.ago)
    Review.create!(
      user: author_user, rule: rule_a, action: 'comment',
      comment: 'Thanks — fixing the typo in the next revision.',
      section: 'vuln_discussion', responding_to_review_id: accepted.id
    )

    # 5) Non-concur (declined), with the required response in the thread
    declined = Review.create!(
      user: other_voice, rule: rule_b, action: 'comment',
      comment: 'Suggest dropping the rule entirely — most operators will use OPA Gatekeeper instead.',
      section: nil
    )
    declined.update!(triage_status: 'non_concur', triage_set_by_id: author_user.id, triage_set_at: 1.day.ago)
    Review.create!(
      user: author_user, rule: rule_b, action: 'comment',
      comment: "Thanks for raising this. We're keeping the baseline rule for shops not running OPA — happy to add a documentable exception.",
      responding_to_review_id: declined.id
    )

    # 6) Adjudicated (closed) — concur_with_comment that ran through full lifecycle
    closed = Review.create!(
      user: viewer_user, rule: rule_d, action: 'comment',
      comment: 'The artifact description should accept either a screenshot or a CLI transcript, not both.',
      section: 'artifact_description'
    )
    closed.update!(
      triage_status: 'concur_with_comment',
      triage_set_by_id: author_user.id, triage_set_at: 2.days.ago,
      adjudicated_at: 1.day.ago, adjudicated_by_id: author_user.id
    )

    # 7) Informational — auto-adjudicated by the model callback
    Review.create!(
      user: other_voice, rule: rule_c, action: 'comment',
      comment: 'FYI we shipped a similar control in our v1.2 baseline — same wording.',
      triage_status: 'informational',
      triage_set_by_id: author_user.id, triage_set_at: 3.hours.ago
    )

    # 8) Withdrawn (commenter retracted)
    Review.create!(
      user: viewer_user, rule: rule_a, action: 'comment',
      comment: 'Never mind — I see this is already covered by the existing CCI mapping.',
      triage_status: 'withdrawn'
    )

    puts '  Seeded demo comments (Container Platform): pending, concur+response, non_concur+response, adjudicated, informational, withdrawn'
  end

  # ---------------------------------------------------------- #
  # Spread comments across other projects/components so the    #
  # projects-list "Comments" column shows badges across rows   #
  # — not just on Container Platform. Each project gets a      #
  # distinct shape so the totals/pending split is testable.    #
  # ---------------------------------------------------------- #
  cross_project_membership = lambda do |user, project, role|
    Membership.find_or_create_by!(user: user, membership: project) { |m| m.role = role }
  end

  Project.where.not(id: container_platform.id).find_each do |proj|
    next if project_has_comments.call(proj)

    components_with_rules = proj.components.includes(:rules).select { |c| c.rules.any? }
    next if components_with_rules.empty?

    cross_project_membership.call(viewer_user, proj, 'viewer')
    cross_project_membership.call(other_voice, proj, 'viewer')
    cross_project_membership.call(author_user, proj, 'author')

    case proj.name
    when 'Photon 3'
      # Mostly closed, one pending — exercises the "9 total / 1 pending" badge case
      comp = components_with_rules.first
      r = comp.rules.first
      Review.create!(action: 'comment', user: viewer_user, rule: r, section: 'check_content',
                     comment: 'Photon 3 baseline: should the audit rule include CIS Level 1 only?')
      closed = Review.create!(action: 'comment', user: other_voice, rule: r, section: 'fixtext',
                              comment: 'Fix script needs sudo wrapping for non-root execution.')
      closed.update!(triage_status: 'concur', triage_set_by_id: author_user.id, triage_set_at: 2.days.ago,
                     adjudicated_by_id: author_user.id, adjudicated_at: 1.day.ago)
      r2 = comp.rules.second
      Review.create!(action: 'comment', user: viewer_user, rule: r2, section: nil,
                     comment: 'FYI we already shipped this in our internal hardening guide.',
                     triage_status: 'informational',
                     triage_set_by_id: author_user.id,
                     triage_set_at: 1.day.ago)

    when 'Photon 4'
      # Multiple pending across multiple components — exercises the
      # /projects/:id#comments fallback link (no single-component target).
      components_with_rules.first(2).each_with_index do |comp, idx|
        Review.create!(action: 'comment', user: viewer_user, rule: comp.rules.first,
                       section: 'vuln_discussion',
                       comment: "Photon 4 component #{idx + 1}: vuln discussion para 2 typo.")
        Review.create!(action: 'comment', user: other_voice, rule: comp.rules.first,
                       section: 'check_content',
                       comment: "Photon 4 component #{idx + 1}: check command needs --no-pager flag.")
      end

    when 'vSphere 7.0'
      # Single pending on a single component — exercises the
      # /components/:id#comments single-target link from the list.
      comp = components_with_rules.first
      Review.create!(action: 'comment', user: viewer_user, rule: comp.rules.first,
                     section: 'fixtext',
                     comment: 'vSphere 7.0: fix command targets ESXi 6.7 path — should reference 7.0 layout.')
    end
  end
  puts '  Seeded cross-project demo comments (Photon 3, Photon 4, vSphere 7.0)'
end

# rubocop:enable Rails/Output
