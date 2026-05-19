# frozen_string_literal: true

# rubocop:disable Rails/Output
puts 'Seeding cross-project demo comments...'

container_platform = Project.find_by(name: 'Container Platform')
viewer_user = User.find_by(email: 'viewer@example.com')
author_user = User.find_by(email: 'author@example.com')
other_voice = User.where.not(id: [viewer_user&.id, author_user&.id].compact)
                  .where(admin: [false, nil]).first || viewer_user

cross_project_membership = lambda do |user, project, role|
  Membership.find_or_create_by!(user: user, membership: project) { |m| m.role = role }
end

Project.where.not(id: container_platform&.id).find_each do |proj|
  components_with_rules = proj.components.includes(:rules).select { |c| c.rules.any? }
  next if components_with_rules.empty?

  # Skip if this project already has comments
  has_comments = Review.where(action: 'comment', responding_to_review_id: nil)
                       .joins(:rule)
                       .merge(Rule.where(component: proj.components))
                       .exists?
  next if has_comments

  cross_project_membership.call(viewer_user, proj, 'viewer')
  cross_project_membership.call(other_voice, proj, 'viewer')
  cross_project_membership.call(author_user, proj, 'author')

  # rubocop:disable Style/CaseLikeIf
  if proj.name == 'Photon 3'
    comp = components_with_rules.first
    r = comp.rules.first

    SeedHelpers.find_or_seed_review(
      rule: r, user: viewer_user, section: 'check_content',
      comment: 'Photon 3 baseline: should the audit rule include CIS Level 1 only?'
    )

    closed = SeedHelpers.find_or_seed_review(
      rule: r, user: other_voice, section: 'fixtext',
      comment: 'Fix script needs sudo wrapping for non-root execution.'
    )
    SeedHelpers.seed_triage(closed, user: author_user, status: 'concur')
    closed.update!(adjudicated_by_id: author_user.id, adjudicated_at: 1.day.ago) if closed.adjudicated_at.blank?

    r2 = comp.rules.second
    if r2
      info = SeedHelpers.find_or_seed_review(
        rule: r2, user: viewer_user, section: nil,
        comment: 'FYI we already shipped this in our internal hardening guide.'
      )
      SeedHelpers.seed_triage(info, user: author_user, status: 'informational')
    end

  elsif proj.name == 'Photon 4'
    components_with_rules.first(2).each_with_index do |comp, idx|
      SeedHelpers.find_or_seed_review(
        rule: comp.rules.first, user: viewer_user, section: 'vuln_discussion',
        comment: "Photon 4 component #{idx + 1}: vuln discussion para 2 typo."
      )
      SeedHelpers.find_or_seed_review(
        rule: comp.rules.first, user: other_voice, section: 'check_content',
        comment: "Photon 4 component #{idx + 1}: check command needs --no-pager flag."
      )
    end

  elsif proj.name == 'vSphere 7.0'
    comp = components_with_rules.first
    SeedHelpers.find_or_seed_review(
      rule: comp.rules.first, user: viewer_user, section: 'fixtext',
      comment: 'vSphere 7.0: fix command targets ESXi 6.7 path — should reference 7.0 layout.'
    )
  end
  # rubocop:enable Style/CaseLikeIf
end

puts '  Cross-project comments seeded'
# rubocop:enable Rails/Output
