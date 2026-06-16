# frozen_string_literal: true

# rubocop:disable Rails/Output
puts 'Seeding project access requests...'

# Make vSphere 7.0 discoverable so non-members can find and request access
vsphere = Project.find_by(name: 'vSphere 7.0')
if vsphere && vsphere.visibility != 'discoverable'
  vsphere.update!(visibility: 'discoverable')
  puts '  Set vSphere 7.0 to discoverable'
end

# Create a non-member user who wants to join vSphere 7.0
if vsphere
  requester = User.find_or_initialize_by(email: 'requester@example.com')
  if requester.new_record?
    requester.name = 'Access Requester'
    requester.password = requester.password_confirmation = SeedHelpers::DEMO_PASSWORD
    requester.skip_confirmation!
    requester.save!
    puts "  Created requester user: #{requester.email}"
  end

  # Remove any existing membership so the access request makes sense
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
