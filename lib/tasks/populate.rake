# frozen_string_literal: true

namespace :db do
  desc 'Populate the database for demo use'
  task populate: :environment do
    raise 'This task is only for use in a development environment' unless Rails.env.development?

    puts "Populating database for demo use:\n\n"

    puts 'Populating users...'
    User.create(name: FFaker::Name.name, email: 'admin@example.com', password: '1234567ab!', admin: true)
    10.times { |i| User.create(name: FFaker::Name.name, email: "user#{i}@example.com", password: '1234567ab!') }
    puts 'Done populating users.'
  end
end
