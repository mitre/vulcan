# frozen_string_literal: true

# rubocop:disable Rails/Output

# SRG authoring demo — one srg-kind component with authored requirements
# across the three lifecycle states, so SRG paths (editor, triage, pickers,
# exports) have demo data. Derived from the seeded Application Core SRG:
# srg-kind components require a core parent. All requirement text here is
# synthetic; the shape (mostly-justified NA, a few Applicable, pending
# comments spread across rows) mirrors a real ratified SRG component.
puts 'Seeding SRG authoring demo...'

core_srg = SecurityRequirementsGuide.find_by(srg_id: 'Application_Core_SRG')
if core_srg.nil?
  puts '  Application Core SRG not seeded — skipping SRG authoring demo'
  return
end

demo_project = Project.find_or_create_by!(name: 'SRG Authoring Demo')

demo_admin = User.find_by(admin: true)
{
  'viewer@example.com' => 'viewer',
  'author@example.com' => 'author',
  'reviewer@example.com' => 'reviewer'
}.each do |email, role|
  user = User.find_by(email: email)
  next unless user

  Membership.find_or_create_by!(user: user, membership: demo_project) do |m|
    m.role = role
  end
end
Membership.find_or_create_by!(user: demo_admin, membership: demo_project) { |m| m.role = 'admin' } if demo_admin

demo_component = SeedHelpers.seed_component(
  project: demo_project, name: 'Demo Application SRG',
  title: 'Demo Application SRG (Authoring Sample)',
  prefix: 'DSRG-00', based_on: core_srg,
  document_type: 'srg', skip_import_srg_rules: true,
  admin_name: 'SRG Author Team', admin_email: 'srg-authors@example.com',
  comment_phase: 'open',
  comment_period_starts_at: 1.day.ago,
  comment_period_ends_at: 30.days.from_now
)

# Authored requirements: 2 Applicable, 4 Not Applicable (justified), 2 Not
# Yet Determined. Seven derive from core catalog rows; the last is net-new.
core_rows = core_srg.srg_rules.order(:version).limit(7).to_a
na_justification = 'The demonstration application delegates this capability to the ' \
                   'underlying platform, so the requirement is satisfied outside this scope.'

requirement_rows = [
  { rule_id: '000001', status: 'Applicable',
    title: 'The application must enforce approved authorizations for logical access to demonstration resources.' },
  { rule_id: '000002', status: 'Applicable',
    title: 'The application must generate audit records for demonstration account activity.' },
  { rule_id: '000003', status: 'Not Applicable', justification: na_justification,
    title: 'The application must manage demonstration network sessions established on its behalf.' },
  { rule_id: '000004', status: 'Not Applicable', justification: na_justification,
    title: 'The application must protect demonstration data at rest on removable media.' },
  { rule_id: '000005', status: 'Not Applicable', justification: na_justification,
    title: 'The application must terminate demonstration sessions after an organization-defined idle period.' },
  { rule_id: '000006', status: 'Not Applicable', justification: na_justification,
    title: 'The application must enforce demonstration password lifetime restrictions.' },
  { rule_id: '000007', status: 'Not Yet Determined',
    title: 'The application must limit concurrent demonstration sessions per account.' },
  { rule_id: '000008', status: 'Not Yet Determined', net_new: true,
    title: 'The application must display the demonstration usage banner before granting access.' }
]

requirement_rows.each_with_index do |row, index|
  SrgRule.find_or_create_by!(component: demo_component, rule_id: row[:rule_id]) do |r|
    r.title = row[:title]
    r.status = row[:status]
    r.status_justification = row[:justification]
    r.rule_severity = 'medium'
    r.rule_weight = '10.0'
    r.ident = 'CCI-000366'
    r.derived_from = core_rows[index] unless row[:net_new]
  end
end
demo_component.reload

# Pending comments spread across rows (the dominant shape on a component in
# an open comment period) plus one reply thread.
viewer = User.find_by(email: 'viewer@example.com')
requirements_by_rule_id = demo_component.requirements.index_by(&:rule_id)

if viewer
  first_comment = SeedHelpers.find_or_seed_review(
    rule: requirements_by_rule_id['000001'], user: viewer, section: 'check_content',
    comment: 'Should this authorization requirement name the demonstration role model explicitly?'
  )
  SeedHelpers.find_or_seed_review(
    rule: requirements_by_rule_id['000003'], user: viewer, section: 'vuln_discussion',
    comment: 'The platform-delegation justification could cite where the capability is inherited from.'
  )
  SeedHelpers.find_or_seed_review(
    rule: requirements_by_rule_id['000007'], user: viewer, section: 'check_content',
    comment: 'Is a concurrent-session limit measurable for the demonstration deployment model?'
  )

  author = User.find_by(email: 'author@example.com')
  if author
    SeedHelpers.find_or_seed_reply(
      parent: first_comment, user: author,
      comment: 'Good catch — the role model reference is being drafted for the next revision.'
    )
  end
end

puts "  #{demo_component.name}: #{demo_component.requirements.count} authored requirements, " \
     "#{Review.where(commentable: demo_component.requirements).count} comments"
# rubocop:enable Rails/Output
