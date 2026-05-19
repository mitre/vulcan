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
  user = User.find_or_initialize_by(email: email)
  if user.new_record?
    user.name = attrs[:name]
    user.password = SeedHelpers::DEMO_PASSWORD
    user.skip_confirmation!
    user.save!
    puts "  Created #{email} (#{attrs[:role]} tier)"
  else
    puts "  Already exists: #{email}"
  end
end

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
