# frozen_string_literal: true

# rubocop:disable Rails/Output
puts 'Creating STIGs...'
stig_dir = Rails.root.join('db/seeds/stigs')
Dir.glob(stig_dir.join('*.xml')).each do |filepath|
  SeedHelpers.seed_xccdf(filepath)
end
puts "  #{Stig.count} STIGs total"
# rubocop:enable Rails/Output
