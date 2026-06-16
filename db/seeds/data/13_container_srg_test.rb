# frozen_string_literal: true

# rubocop:disable Rails/Output

CONTAINER_SRG_TEST_ZIP = Rails.root.join('db/seeds/backups/container_srg_test.zip')
CONTAINER_SRG_PROJECT_NAME = 'Container SRG Test'

unless File.exist?(CONTAINER_SRG_TEST_ZIP)
  puts 'Skipping Container SRG Test seed — zip not found'
  return
end

project = Project.find_by(name: CONTAINER_SRG_PROJECT_NAME)
if project&.components&.any?
  rule_ids = Rule.where(component_id: project.components.ids).pluck(:id)
  review_count = Review.where(commentable_type: 'BaseRule', commentable_id: rule_ids).count
  if review_count > 100
    puts "Container SRG Test already seeded (#{review_count} reviews) — skipping"
    return
  end
end

puts 'Seeding Container SRG Test via JSON Archive importer...'

# Ensure community personas exist
SeedHelpers::COMMUNITY_PERSONAS.each do |email, attrs|
  user = User.find_or_initialize_by(email: email)
  next unless user.new_record?

  user.name = attrs[:name]
  user.password = SeedHelpers::DEMO_PASSWORD
  user.skip_confirmation!
  user.save!
  puts "  Created community persona: #{email}"
end

project ||= Project.find_or_create_by!(name: CONTAINER_SRG_PROJECT_NAME)
puts "  Project: #{project.name} (id: #{project.id})"

# Wire memberships for all personas + demo users
demo_admin = User.find_by(admin: true)
membership_map = {
  'viewer@example.com' => 'viewer',
  'author@example.com' => 'author',
  'reviewer@example.com' => 'reviewer'
}
SeedHelpers::COMMUNITY_PERSONAS.each do |email, attrs|
  membership_map[email] = attrs[:role]
end

membership_map.each do |email, role|
  user = User.find_by(email: email)
  next unless user

  Membership.find_or_create_by!(user: user, membership: project) do |m|
    m.role = role
  end
end
Membership.find_or_create_by!(user: demo_admin, membership: project) { |m| m.role = 'admin' } if demo_admin

# Import via the production importer
zip_file = Rack::Test::UploadedFile.new(CONTAINER_SRG_TEST_ZIP.to_s, 'application/zip')
result = Import::JsonArchiveImporter.new(
  zip_file: zip_file,
  project: project,
  include_reviews: true,
  imported_by: demo_admin
).call

if result.success?
  puts "  Import result: #{result.summary}"
  puts '  Container SRG Test seeded successfully'
else
  puts "  Import FAILED: #{result.errors.join(', ')}"
end

# rubocop:enable Rails/Output
