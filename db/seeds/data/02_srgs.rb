# frozen_string_literal: true

# rubocop:disable Rails/Output
puts 'Creating SRGs...'
srg_dir = Rails.root.join('db/seeds/srgs')
Dir.glob(srg_dir.join('*.xml')).each do |filepath|
  SeedHelpers.seed_xccdf(filepath)
end
puts "  #{SecurityRequirementsGuide.count} SRGs total"
# rubocop:enable Rails/Output
