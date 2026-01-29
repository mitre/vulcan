# frozen_string_literal: true

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
      admin_password = Devise.friendly_token(32)
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
