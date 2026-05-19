# frozen_string_literal: true

# rubocop:disable Rails/Output
puts 'Creating Projects...'
Project.find_or_create_by!(name: 'Photon 3')
Project.find_or_create_by!(name: 'Photon 4')
Project.find_or_create_by!(name: 'vSphere 7.0')
Project.find_or_create_by!(name: 'Container Platform')
Project.find_or_create_by!(name: 'Nothing to See Here')
puts "  #{Project.count} projects total"
# rubocop:enable Rails/Output
