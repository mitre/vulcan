# frozen_string_literal: true

# rubocop:disable Rails/Output
puts 'Adding Users to Projects...'

demo_projects = Project.where(name: ['Photon 3', 'Photon 4', 'vSphere 7.0', 'Container Platform'])

# All users get viewer membership on all demo projects
demo_projects.each do |project|
  User.find_each do |user|
    Membership.find_or_create_by!(user: user, membership_id: project.id, membership_type: 'Project')
  end
end
puts '  All users added to demo projects'

# Upgrade role-tier users to their assigned roles
puts 'Setting demo role tiers on projects...'
role_map = {
  'viewer@example.com' => 'viewer',
  'author@example.com' => 'author',
  'reviewer@example.com' => 'reviewer'
}

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

# Demo admin gets admin role on all demo projects
demo_admin = User.find_by(admin: true)
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
