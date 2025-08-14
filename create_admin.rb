# frozen_string_literal: true

User.create!(
  email: 'admin@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  admin: true,
  name: 'Admin User'
)
puts 'Admin user created: admin@example.com / password123'
