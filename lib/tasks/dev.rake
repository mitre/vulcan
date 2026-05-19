# frozen_string_literal: true

namespace :dev do
  desc 'Load demo data idempotently (alias for db:seed)'
  task prime: :environment do
    Rake::Task['db:seed'].reenable
    Rake::Task['db:seed'].invoke
  end

  desc 'Report seed data status (record counts per model)'
  task status: :environment do
    require_relative '../seed_helpers'

    puts 'Vulcan seed data status:'
    puts '-' * 40
    SeedHelpers.status_report.each do |model, count|
      puts format('  %-15<model>s %<count>d', model: model, count: count)
    end
    puts '-' * 40
  end

  desc 'Verify seed data completeness and consistency'
  task verify: :environment do
    require_relative '../seed_helpers'

    errors = SeedHelpers.verify!
    if errors.empty?
      puts '✅ All seed data verified'
    else
      puts '❌ Seed verification failed:'
      errors.each { |e| puts "  - #{e}" }
      exit 1
    end
  end

  desc 'Clear demo data and re-prime (preserves admin bootstrap users)'
  task reset: :environment do
    require_relative '../seed_helpers'

    puts 'Clearing demo data...'
    count = Review.where(action: 'comment').count
    Review.where(action: 'comment').destroy_all
    puts "  Deleted #{count} comments"

    puts 'Re-priming...'
    Rake::Task['db:seed'].reenable
    Rake::Task['db:seed'].invoke
    puts 'Done.'
  end
end
