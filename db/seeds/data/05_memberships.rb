# frozen_string_literal: true

# rubocop:disable Rails/Output
puts 'Adding Users to Projects...'

demo_projects = Project.where(name: ['Photon 3', 'Photon 4', 'vSphere 7.0', 'Container Platform'])

# All users get viewer membership on all demo projects — except pairs with a
# pending access request: a pending request means the user is deliberately not
# a member of that project (the request-access flow needs a real non-member).
demo_projects.each do |project|
  pending_requester_ids = ProjectAccessRequest.where(project: project).select(:user_id)
  User.where.not(id: pending_requester_ids).find_each do |user|
    Membership.find_or_create_by!(user: user, membership_id: project.id, membership_type: 'Project')
  end
end
puts '  All users added to demo projects (pending access requesters excluded)'

# Upgrade role-tier users and community personas to their assigned roles
puts 'Setting demo role tiers on projects...'
role_map = SeedHelpers::DEMO_ROLE_USERS.transform_values { |v| v[:role] }
                                       .merge(SeedHelpers::COMMUNITY_PERSONAS.transform_values { |v| v[:role] })

role_map.each do |email, role|
  user = User.find_by(email: email)
  next unless user

  demo_projects.each do |project|
    membership = Membership.find_or_initialize_by(
      user: user,
      membership_type: 'Project',
      membership_id: project.id
    )
    next if membership.role == role

    membership.role = role
    membership.save!
  end
end

# Demo admin gets admin role on all demo projects. Look up by email first —
# multiple site admins exist (api-admin@example.com), so a bare
# find_by(admin: true) would be nondeterministic.
demo_admin = User.find_by(email: 'admin@example.com') || User.where(admin: true).order(:created_at).first
if demo_admin
  demo_projects.each do |project|
    admin_mem = Membership.find_or_create_by!(user: demo_admin, membership_id: project.id, membership_type: 'Project')
    admin_mem.update!(role: 'admin') if admin_mem.role != 'admin'
  end
  puts '  Demo admin promoted to admin on all projects'
end

puts 'Demo role tiers set'

# Reset counter caches to match actual membership counts
Project.find_each { |p| Project.reset_counters(p.id, :memberships_count) }

puts "  #{Membership.count} memberships total"
# rubocop:enable Rails/Output
