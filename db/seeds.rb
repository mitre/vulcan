# frozen_string_literal: true

# rubocop:disable Rails/Output

# Vulcan seed system — modular, idempotent, factory-backed.
#
# Architecture: GitLab/ThoughtBot two-concern pattern.
# - Production seeds (SRGs, STIGs, admin) run on every deploy
# - Demo data (users, projects, comments) is opt-in via env var
#
# See docs/development/seed-system.md for full documentation.
#
# Usage:
#   rails db:seed                                    # dev/test: always seeds
#   VULCAN_SEED_DEMO_DATA=true rails db:seed         # production: opt-in demo
#   rails dev:status                                 # report what's seeded
#   rails dev:verify                                 # check completeness

unless Rails.env.local? || ENV['VULCAN_SEED_DEMO_DATA'] == 'true'
  puts 'Skipping seed data (set VULCAN_SEED_DEMO_DATA=true to populate demo data)'
  return
end

require_relative '../lib/seed_helpers'

SeedHelpers.quiet do
  Rails.root.glob('db/seeds/data/*.rb').each do |seed_file|
    puts "\n=== #{File.basename(seed_file)} ==="
    load(seed_file)
  end
end

puts "\n✅ Seed complete. Run `rails dev:verify` to check data, `rails dev:status` for counts."

# rubocop:enable Rails/Output
