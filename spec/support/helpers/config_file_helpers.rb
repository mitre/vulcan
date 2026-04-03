# frozen_string_literal: true

# Shared helpers for config-file sanity specs.
# Used by specs in spec/config/ that validate file contents, patterns, and consistency.
module ConfigFileHelpers
  # Read a config file and return only non-comment lines as an array of strings.
  def code_lines_for(relative_path)
    Rails.root.join(relative_path).read
         .each_line
         .reject { |l| l.strip.start_with?('#') }
  end

  # Grep non-comment lines of a config file for a pattern. Returns matching lines.
  def grep_config(relative_path, pattern)
    code_lines_for(relative_path).grep(pattern)
  end

  # Grep all Ruby files under a directory for a pattern. Returns "path:line: content" strings.
  def grep_ruby_dir(relative_dir, pattern)
    matches = []
    Rails.root.glob("#{relative_dir}/**/*.rb").each do |file|
      File.readlines(file).each_with_index do |line, idx|
        next if line.strip.start_with?('#')

        matches << "#{Pathname.new(file).relative_path_from(Rails.root)}:#{idx + 1}: #{line.strip}" if line.match?(pattern)
      end
    end
    matches
  end
end

RSpec.configure do |config|
  config.include ConfigFileHelpers, file_path: %r{spec/config/}
  config.include ConfigFileHelpers, file_path: %r{spec/mailers/}
end
