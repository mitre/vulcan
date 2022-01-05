# frozen_string_literal: true

namespace :admin do
  desc 'Backup the database'
  task backup_database: :environment do
    database = ActiveRecord::Base.connection.current_database
    system "pg_dump #{database} > vulcan_database_#{Time.now.to_i}.sql"
  end

  desc 'Restore the database'
  task restore_database: :environment do
    # Example usage: rake admin:restore_database FILE=vulcan_database_1606835867.sql

    Rake::Task["db:drop"].invoke
    Rake::Task["db:create"].invoke

    database = ActiveRecord::Base.connection.current_database
    system "psql -d #{database} -f #{ENV['FILE']}"
  end
end
