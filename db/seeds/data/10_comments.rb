# frozen_string_literal: true

# rubocop:disable Rails/Output
puts 'Seeding demo comments for public-comment-review workflow...'

container_platform = Project.find_by(name: 'Container Platform')
container_component = container_platform&.components&.find_by(name: 'Container Platform')

if container_component.nil?
  puts '  No Container Platform component — skipping comment seeds'
  return
end

if container_component.rules.count < 4
  puts "  Not enough rules on Container Platform (#{container_component.rules.count}) — skipping"
  return
end

# ── Resolve demo users ──
demo_admin = User.find_by(admin: true)
viewer_user = User.find_by(email: 'viewer@example.com') || demo_admin
author_user = User.find_by(email: 'author@example.com') || demo_admin
reviewer_user = User.find_by(email: 'reviewer@example.com') || demo_admin
other_voice = User.where.not(id: [viewer_user&.id, author_user&.id, demo_admin&.id].compact)
                  .where(admin: [false, nil]).first || viewer_user

# ── Ensure memberships ──
{ viewer_user => 'viewer', author_user => 'author',
  reviewer_user => 'reviewer', other_voice => 'viewer' }.each do |user, role|
  Membership.find_or_create_by!(user: user, membership: container_platform) { |m| m.role = role }
end
admin_mem = Membership.find_or_create_by!(user: demo_admin, membership: container_platform) { |m| m.role = 'admin' }
admin_mem.update!(role: 'admin') if admin_mem.role != 'admin'

rules = container_component.rules.order(:rule_id).limit(6).to_a
rule_a, rule_b, rule_c, rule_d, rule_e, rule_f = rules

# ── Rule A (NYD): TLS 1.2 for container image transport ──
c1 = SeedHelpers.find_or_seed_review(
  rule: rule_a, user: viewer_user, section: 'check_content',
  comment: 'The check says "verify that TLS 1.2 or greater is being used for secure container image transport" but does not specify HOW to verify — should it reference openssl s_client or a specific container runtime CLI flag?'
)

c2 = SeedHelpers.find_or_seed_review(
  rule: rule_a, user: reviewer_user, section: 'check_content',
  comment: 'Agree with the previous comment — the check procedure needs a concrete verification command. Also, "from trusted sources" is vague; should we enumerate what constitutes a trusted registry?'
)

SeedHelpers.find_or_seed_review(
  rule: rule_a, user: author_user, section: 'check_content',
  comment: 'This appears to duplicate the first comment about the check verification method — same concern about missing CLI commands.'
)

SeedHelpers.find_or_seed_reply(parent: c1, user: author_user,
                               comment: 'Good point about the missing verification command. We will add an example using "openssl s_client -connect registry:443" and a note about checking containerd mirror config.')

SeedHelpers.find_or_seed_reply(parent: c2, user: author_user,
                               comment: 'We will add "trusted sources" definition: registries listed in the platform allowlist config (e.g., /etc/containerd/certs.d/).')

c4 = SeedHelpers.find_or_seed_review(
  rule: rule_a, user: viewer_user, section: 'fixtext',
  comment: 'The fix text says "Configure the container platform to use TLS 1.2 or greater when components communicate internally or externally" — this is too broad. It should specify which configuration files to modify (e.g., /etc/containerd/config.toml, registry mirror config).'
)

SeedHelpers.find_or_seed_reply(parent: c4, user: reviewer_user,
                               comment: 'Agree — the fix should distinguish between registry pull config and inter-node communication config. They are different settings.')

SeedHelpers.find_or_seed_review(
  rule: rule_a, user: reviewer_user, section: 'vuln_discussion',
  comment: 'The vulnerability discussion references "the overall security posture" but does not mention the specific risk of image tampering via MITM on unencrypted registries. Consider adding a sentence about supply chain integrity.'
)

# ── Rule B (NYD): TLS 1.2 for node communication ──
SeedHelpers.find_or_seed_review(
  rule: rule_b, user: viewer_user, section: 'fixtext',
  comment: 'Fix text says "for node and component communication" — should clarify whether this includes etcd peer communication and kubelet-to-API-server, or just external-facing endpoints.'
)

c7 = SeedHelpers.find_or_seed_review(
  rule: rule_b, user: reviewer_user, section: nil,
  comment: 'This rule overlaps significantly with rule 000001 (both require TLS 1.2). Consider whether they should be consolidated or cross-referenced to avoid duplicate compliance checks.'
)
SeedHelpers.seed_triage(c7, user: author_user, status: 'non_concur')

SeedHelpers.find_or_seed_reply(parent: c7, user: author_user,
                               comment: 'We considered consolidating but they address different trust boundaries: image transport (registry pull) vs. node-to-node (cluster internal). Keeping separate for auditability.')

# ── Rule C (NYD): Centralized user management ──
SeedHelpers.find_or_seed_review(
  rule: rule_c, user: reviewer_user, section: nil,
  comment: 'The check says to verify "a centralized user management system" — LDAP and OIDC are both valid. Suggest adding examples (LDAP, SAML, OIDC) to the check procedure for clarity.'
)

c9 = SeedHelpers.find_or_seed_review(
  rule: rule_c, user: reviewer_user, section: nil,
  comment: 'FYI — our v1.2 baseline already ships this same requirement with identical wording from the SRG. No changes needed.'
)
SeedHelpers.seed_triage(c9, user: author_user, status: 'informational')

# ── Rule D (NYD): Temp accounts disabled after 72h ──
c10 = SeedHelpers.find_or_seed_review(
  rule: rule_d, user: viewer_user, section: 'check_content',
  comment: 'The check says to verify temp accounts are "automatically removed or disabled after 72 hours" — most platforms handle this via RBAC token expiry, not account deletion. Should the check mention token TTL as an acceptable mechanism?'
)
SeedHelpers.seed_triage(c10, user: author_user, status: 'concur_with_comment')

SeedHelpers.find_or_seed_reply(parent: c10, user: author_user,
                               comment: 'Good observation. We will add token TTL as an acceptable implementation alongside account disablement.')

# ── Rule E (AC): Disable inactive accounts after 35 days ──
SeedHelpers.find_or_seed_review(
  rule: rule_e, user: viewer_user, section: 'check_content',
  comment: 'The check says "Determine if the container platform automatically disables accounts after a 35-day period of account inactivity" — clear and actionable. No changes needed.'
)

SeedHelpers.find_or_seed_review(
  rule: rule_e, user: reviewer_user, section: 'fixtext',
  comment: 'Fix text says "Configure the container platform to automatically disable accounts after a 35-day period" — this is the SRG default. Should specify which platform-specific setting controls inactivity timeout (e.g., for OIDC providers, this is configured at the IdP level).'
)

c13 = SeedHelpers.find_or_seed_review(
  rule: rule_e, user: reviewer_user, section: 'severity',
  comment: 'Medium severity is appropriate for account inactivity. Concur.'
)
SeedHelpers.seed_triage(c13, user: author_user, status: 'concur')

# ── Rule F (NA): Audit account creation ──
SeedHelpers.find_or_seed_review(
  rule: rule_f, user: viewer_user, section: 'status',
  comment: 'Agree this is Not Applicable — container platforms delegate account creation to external identity providers (LDAP/OIDC). The platform itself does not create accounts; it only maps external identities to RBAC roles.'
)

# ── Rule A: disa_metadata section (advanced fields) ──
SeedHelpers.find_or_seed_review(
  rule: rule_a, user: reviewer_user, section: 'disa_metadata',
  comment: 'The DISA metadata fields (documentable, mitigations) are empty. Per the Vendor STIG Process Guide §4.1, documentable should be set to "false" for container-platform requirements that rely on external tooling for evidence collection.'
)

# ── Rule A: withdrawn comment ──
c_withdrawn = SeedHelpers.find_or_seed_review(
  rule: rule_a, user: viewer_user, section: nil,
  comment: 'Never mind — I see that the TLS 1.2 requirement is already covered by the CCI mapping to CCI-001453. Retracting this comment.'
)
SeedHelpers.seed_triage(c_withdrawn, user: viewer_user, status: 'withdrawn')

# ── Component-scoped (no rule) ──
comp_text_one = 'Overall the STIG draft is well-structured and the SRG mappings are accurate. Suggest cross-referencing the CIS Container Benchmark for implementations that address multiple SRG requirements with a single control.'
unless Review.exists?(action: 'comment', comment: comp_text_one)
  Review.create!(user: viewer_user, commentable: container_component, action: 'comment',
                 section: nil, comment: comp_text_one)
end

comp_text_two = 'Consider noting in the overview which requirements are inherited from the host OS STIG vs. those that are container-platform-specific. This helps implementers scope their compliance work.'
unless Review.exists?(action: 'comment', comment: comp_text_two)
  Review.create!(user: reviewer_user, commentable: container_component, action: 'comment',
                 section: nil, comment: comp_text_two)
end

top_level = Review.where(action: 'comment', responding_to_review_id: nil).count
replies = Review.where(action: 'comment').where.not(responding_to_review_id: nil).count
puts "  Container Platform: #{top_level} top-level + #{replies} replies"
# rubocop:enable Rails/Output
