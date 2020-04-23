# frozen_string_literal: true

require 'highline'

namespace :db do
  desc 'Setup administrator in the database'
  task create_admin: :environment do
    puts 'This task will create a user account and make that user an administrator.'
    ui = HighLine.new
    email = ui.ask('Your Email: ')
    password = ui.ask('Enter password: ') { |q| q.echo = false }
    confirm  = ui.ask('Confirm password: ') { |q| q.echo = false }

    user = DbUser.new(email: email, password: password, password_confirmation: confirm)
    user.add_role(:admin)
    if user.save
      puts "User account '#{email}' created."
    else
      puts
      puts 'Problem creating user account:'
      puts user.errors.full_messages
    end
  end
end
