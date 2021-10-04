# frozen_string_literal: true

# rubocop:disable Rails/Output

# Populate the database for demonstration use.
unless Rails.env.development? || ENV.fetch('DISABLE_DATABASE_ENVIRONMENT_CHECK', false)
  raise 'This task is only for use in a development environment'
end

puts "Populating database for demo use:\n\n"
puts 'Creating Users...'
User.create(name: FFaker::Name.name, email: 'admin@example.com', password: '1234567ab!', admin: true)
users = []
10.times do
  name = FFaker::Name.name
  users << User.new(name: name, email: "#{name.split.join('.')}@example.com", password: '1234567ab!')
end
User.import(users)
puts 'Created Users'
puts 'Creating SRG...'
srg_xml = File.read('./spec/fixtures/files/U_Web_Server_V2R3_Manual-xccdf.xml')
parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
srg.xml = srg_xml
srg.save!
puts 'Created SRG'
puts 'Creating Components with rules...'
component1 = Project.create(
  name: 'Test Component 1',
  prefix: 'ABCD-01',
  based_on: srg
)
Project.from_mapping(Xccdf::Benchmark.parse(component1.based_on.xml), component1.id)

component2 = Project.create(
  name: 'Test Component 2',
  prefix: 'ZZZZ-41',
  based_on: srg
)
Project.from_mapping(Xccdf::Benchmark.parse(component2.based_on.xml), component2.id)
puts 'Created Components with Rules'

puts 'Creating Projects...'
project1 = Project.create(name: 'Test Project 1')
Component.create(project: project1, child_project: component1)
puts 'Created Projects'

puts 'Adding Users to Projects...'
project_members = []
User.all.each do |user|
  project_members << ProjectMember.new(user: user, project: component1)
  project_members << ProjectMember.new(user: user, project: component2)
  project_members << ProjectMember.new(user: user, project: project1)
end
ProjectMember.import(project_members)
puts 'Project Members added'

# Counter cache update
Project.all.each { |p| Project.reset_counters(p.id, :project_members) }
# rubocop:enable Rails/Output
