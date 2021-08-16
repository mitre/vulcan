# frozen_string_literal: true

# rubocop:disable Rails/Output

# Populate the database for demonstration use.
unless Rails.env.development? || ENV.fetch(DISABLE_DATABASE_ENVIRONMENT_CHECK, false)
  raise 'This task is only for use in a development environment'
end

puts "Populating database for demo use:\n\n"
puts 'Creating Users...'
User.create(name: FFaker::Name.name, email: 'admin@example.com', password: '1234567ab!', admin: true)
users = []
10.times do |i|
  name = FFaker::Name.name
  users << User.new(name: name, email: "#{name.split.join('.')}@example.com", password: '1234567ab!')
end
User.import(users)
puts 'Created Users'
puts 'Creating Projects with rules...'
project = Project.create(name: 'Test Project')
rules = []
10.times do
  rules << Rule.new(
    project: project,
    rule_id: "SV-#{rand(99_999)}r1_rule"
  )
end
Rule.import(rules)
puts 'Created Rules'

puts 'Adding Users to Projects...'
project_members = []
User.all.each do |user|
  project_members << ProjectMember.new(user: user, project: project)
end
ProjectMember.import(project_members)
puts 'Project Members added'
# rubocop:enable Rails/Output
