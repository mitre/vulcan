# frozen_string_literal: true

# Sync the VERSION file to package.json and lib/vulcan/version.rb.
# Run after bumping the VERSION file (or let release-please handle it).
namespace :version do
  desc 'Sync VERSION file to package.json'
  task sync: :environment do
    require_relative '../vulcan/version'
    version = Vulcan::VERSION

    # Update package.json
    package_path = Rails.root.join('package.json')
    package = JSON.parse(package_path.read)
    if package['version'] == version
      puts "package.json already at #{version}"
    else
      package['version'] = version
      package_path.write("#{JSON.pretty_generate(package)}\n")
      puts "Updated package.json to #{version}"
    end
  end
end
