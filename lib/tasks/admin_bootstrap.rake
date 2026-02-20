# frozen_string_literal: true

# Generates a random password that meets the configured complexity policy
def generate_compliant_password
  p = Settings.password
  base = Devise.friendly_token(20)
  # Append enough of each required character type to meet minimums
  suffix = ''
  suffix += 'A' * p.min_uppercase.to_i if p.min_uppercase.to_i.positive?
  suffix += 'a' * p.min_lowercase.to_i if p.min_lowercase.to_i.positive?
  suffix += '1' * p.min_number.to_i if p.min_number.to_i.positive?
  suffix += '!' * p.min_special.to_i if p.min_special.to_i.positive?
  password = base + suffix
  min = p.min_length.to_i
  password = password.ljust(min, 'x') if password.length < min
  password
end

namespace :admin do
  desc 'Bootstrap admin user from environment variables (VULCAN_ADMIN_EMAIL, VULCAN_ADMIN_PASSWORD)'
  task bootstrap: :environment do
    admin_email = ENV.fetch('VULCAN_ADMIN_EMAIL', nil)
    admin_password = ENV.fetch('VULCAN_ADMIN_PASSWORD', nil)

    # Skip if no admin email is configured
    if admin_email.blank?
      Rails.logger.info 'No VULCAN_ADMIN_EMAIL set, skipping admin bootstrap'
      next
    end

    # Skip if admin already exists (any admin, not just this email)
    if User.exists?(admin: true)
      Rails.logger.info 'Admin user already exists, skipping bootstrap'
      next
    end

    # Check if user with this email already exists
    existing_user = User.find_by(email: admin_email.downcase)

    if existing_user
      # Promote existing user to admin
      existing_user.update!(admin: true)
      Rails.logger.info "Existing user #{admin_email} promoted to admin"
      next
    end

    # Generate password if not provided
    generated_password = false
    if admin_password.blank?
      admin_password = generate_compliant_password
      generated_password = true
    end

    # Create new admin user
    user = User.new(
      email: admin_email,
      password: admin_password,
      password_confirmation: admin_password,
      name: 'Admin',
      admin: true
    )
    user.skip_confirmation!

    if user.save
      Rails.logger.info "Admin user #{admin_email} created successfully"
      if generated_password
        Rails.logger.warn "Generated temporary password for #{admin_email}: #{admin_password}"
        Rails.logger.warn 'Please change this password immediately after first login!'
      end
    else
      Rails.logger.error "Failed to create admin user: #{user.errors.full_messages.join(', ')}"
    end
  end
end

# Hook into db:prepare to run admin bootstrap automatically
Rake::Task['db:prepare'].enhance do
  Rake::Task['admin:bootstrap'].invoke if Rake::Task.task_defined?('admin:bootstrap')
end
