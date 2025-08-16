# frozen_string_literal: true

# This script is for development and testing use only
unless Rails.env.local?
  raise 'ERROR: This script is only for use in development or test environments. ' \
        'Creating admin@example.com in production is a security risk!'
end

User.create!(
  email: 'admin@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  admin: true,
  name: 'Admin User'
)
puts 'Admin user created: admin@example.com / password123'
puts 'WARNING: This account is for development/testing only!'
