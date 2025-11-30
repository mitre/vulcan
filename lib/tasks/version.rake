# frozen_string_literal: true

namespace :version do
  desc 'Display current Vulcan version'
  task show: :environment do
    version = File.read('VERSION').strip
    puts "Vulcan v#{version}"
  end

  desc 'Sync package.json version from VERSION file'
  task sync: :environment do
    version = File.read('VERSION').strip
    package_json_path = Rails.root.join('package.json')
    package_data = JSON.parse(File.read(package_json_path))

    old_version = package_data['version']
    package_data['version'] = version

    File.write(package_json_path, "#{JSON.pretty_generate(package_data)}\n")

    if old_version == version
      puts "✅ package.json already at version #{version}"
    else
      puts "✅ Updated package.json: #{old_version} → #{version}"
    end
  end

  desc 'Verify VERSION file and package.json are in sync'
  task check: :environment do
    version_file = File.read('VERSION').strip
    package_data = JSON.parse(File.read('package.json'))
    package_version = package_data['version']

    if version_file == package_version
      puts "✅ Versions in sync: #{version_file}"
    else
      puts '❌ Version mismatch!'
      puts "   VERSION file: #{version_file}"
      puts "   package.json: #{package_version}"
      puts ''
      puts 'Run: rails version:sync'
      exit 1
    end
  end

  desc 'Bump patch version (2.3.0 -> 2.3.1)'
  task bump_patch: :environment do
    current = File.read('VERSION').strip
    parts = current.split('.')
    parts[2] = (parts[2].to_i + 1).to_s
    new_version = parts.join('.')

    File.write('VERSION', "#{new_version}\n")
    Rake::Task['version:sync'].invoke

    puts "✅ Bumped patch: #{current} → #{new_version}"
    puts ''
    puts 'Next steps:'
    puts '  1. Update CHANGELOG.md'
    puts '  2. git add VERSION package.json CHANGELOG.md'
    puts "  3. git commit -m 'chore: bump version to #{new_version}'"
    puts "  4. git tag -a v#{new_version} -m 'Release v#{new_version}'"
    puts "  5. git push origin v#{new_version}"
  end

  desc 'Bump minor version (2.3.0 -> 2.4.0)'
  task bump_minor: :environment do
    current = File.read('VERSION').strip
    parts = current.split('.')
    parts[1] = (parts[1].to_i + 1).to_s
    parts[2] = '0'
    new_version = parts.join('.')

    File.write('VERSION', "#{new_version}\n")
    Rake::Task['version:sync'].invoke

    puts "✅ Bumped minor: #{current} → #{new_version}"
    puts ''
    puts 'Next steps:'
    puts '  1. Update CHANGELOG.md'
    puts '  2. git add VERSION package.json CHANGELOG.md'
    puts "  3. git commit -m 'chore: bump version to #{new_version}'"
    puts "  4. git tag -a v#{new_version} -m 'Release v#{new_version}'"
    puts "  5. git push origin v#{new_version}"
  end

  desc 'Bump major version (2.3.0 -> 3.0.0)'
  task bump_major: :environment do
    current = File.read('VERSION').strip
    parts = current.split('.')
    parts[0] = (parts[0].to_i + 1).to_s
    parts[1] = '0'
    parts[2] = '0'
    new_version = parts.join('.')

    File.write('VERSION', "#{new_version}\n")
    Rake::Task['version:sync'].invoke

    puts "⚠️  Bumped MAJOR: #{current} → #{new_version}"
    puts ''
    puts 'This is a BREAKING CHANGE release!'
    puts ''
    puts 'Next steps:'
    puts '  1. Update CHANGELOG.md with breaking changes'
    puts '  2. Update UPGRADE.md with migration guide'
    puts '  3. git add VERSION package.json CHANGELOG.md UPGRADE.md'
    puts "  4. git commit -m 'chore: bump version to #{new_version} (BREAKING)'"
    puts "  5. git tag -a v#{new_version} -m 'Release v#{new_version}'"
    puts "  6. git push origin v#{new_version}"
  end
end
