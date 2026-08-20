# frozen_string_literal: true

# rubocop:disable Rails/Output

# Create demo admin only if no admin exists yet (admin:bootstrap may have already created one)
unless User.exists?(admin: true)
  puts 'Creating demo admin (admin@example.com)...'
  admin = User.new(name: 'Demo Admin', email: 'admin@example.com',
                   password: SeedHelpers::DEMO_PASSWORD, admin: true)
  admin.skip_confirmation!
  admin.save!
  puts "  Demo admin created (password from #{ENV.key?('VULCAN_SEED_ADMIN_PASSWORD') ? 'VULCAN_SEED_ADMIN_PASSWORD env var' : 'default'})"
end

# Demo role-tier users: email-as-role pattern for 30-second login/logout test loop
puts 'Creating demo role-tier users...'
SeedHelpers::DEMO_ROLE_USERS.each do |email, attrs|
  user = SeedHelpers.find_or_create_demo_user(email, name: attrs[:name])
  puts user.previously_new_record? ? "  Created #{email} (#{attrs[:role]} tier)" : "  Already exists: #{email}"
end

# Community SME personas for Container SRG Test dataset (stable, deterministic)
puts 'Creating community SME personas...'
SeedHelpers::COMMUNITY_PERSONAS.each do |email, attrs|
  user = SeedHelpers.find_or_create_demo_user(email, name: attrs[:name])
  puts user.previously_new_record? ? "  Created #{email} (#{attrs[:role]} tier)" : "  Already exists: #{email}"
end

# Dedicated API test users: token owners for scripted API access (site-admin
# and member tiers) so automation never evicts a human browser session.
puts 'Creating API test users...'
SeedHelpers::API_TEST_USERS.each do |email, attrs|
  user = SeedHelpers.find_or_create_demo_user(email, name: attrs[:name], admin: attrs[:admin])
  tier = attrs[:admin] ? 'site admin' : 'member tier'
  puts user.previously_new_record? ? "  Created #{email} (#{tier})" : "  Already exists: #{email}"
end

# Access-request persona: must exist BEFORE 05_memberships runs so the
# membership pass can honor the pending-request invariant (a user with a
# pending access request is deliberately not a member of that project).
puts 'Creating access-request persona...'
requester = SeedHelpers.find_or_create_demo_user('requester@example.com', name: 'Access Requester')
puts requester.previously_new_record? ? '  Created requester@example.com' : '  Already exists: requester@example.com'

# Filler users with random names for realistic project list
demo_emails = SeedHelpers::DEMO_EMAILS
non_demo_count = User.where.not(email: demo_emails).count
if non_demo_count < 5
  puts 'Creating filler users...'
  10.times do
    name = FFaker::Name.name
    email = "#{name.split.join('.')}@example.com".downcase
    next if User.exists?(email: email)

    user = User.new(name: name, email: email, password: SeedHelpers::DEMO_PASSWORD)
    user.skip_confirmation!
    user.save!
  end
  puts "  Created filler users (now #{User.count} total)"
else
  puts '  Filler users already exist, skipping'
end

# rubocop:enable Rails/Output
