# frozen_string_literal: true

# rubocop:disable Rails/Output
puts 'Seeding project access requests...'

# Make vSphere 7.0 discoverable so non-members can find and request access
vsphere = Project.find_by(name: 'vSphere 7.0')
if vsphere && vsphere.visibility != 'discoverable'
  vsphere.update!(visibility: 'discoverable')
  puts '  Set vSphere 7.0 to discoverable'
end

# The requester persona is created in 00_users so it exists before
# 05_memberships runs (all users must exist before the membership pass —
# users created later pick up unintended memberships on the next reseed).
if vsphere
  requester = User.find_by!(email: 'requester@example.com')

  # Remove any vSphere membership so the pending request makes sense. On a
  # fresh seed this undoes the all-users membership pass (the request does
  # not exist yet when 05 runs); once the request exists, 05 skips the pair
  # and this finds nothing. Also repairs dev DBs seeded before the invariant.
  Membership.where(user: requester, membership: vsphere).destroy_all

  ProjectAccessRequest.find_or_create_by!(
    user: requester,
    project: vsphere
  )
  puts "  Access request from #{requester.email} to #{vsphere.name}"
else
  puts '  No vSphere 7.0 project — skipping access requests'
end

puts "  #{ProjectAccessRequest.count} access requests total"
# rubocop:enable Rails/Output
