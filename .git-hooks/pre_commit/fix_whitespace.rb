# frozen_string_literal: true

module Overcommit
  module Hook
    module PreCommit
      # Automatically fixes whitespace issues in staged files
      class FixWhitespace < Base
        def run
          messages = []

          applicable_files.each do |file|
            next unless File.exist?(file)

            # Read file with proper encoding handling
            begin
              original_contents = File.read(file, encoding: 'UTF-8')
            rescue Encoding::InvalidByteSequenceError
              # Skip binary files or files with encoding issues
              next
            end

            # Remove trailing whitespace from each line
            fixed_contents = original_contents.gsub(/[ \t]+$/, '')

            # Convert tabs to spaces (2 spaces per tab)
            fixed_contents = fixed_contents.gsub("\t", '  ')

            # Remove excessive trailing newlines (keep max 1)
            fixed_contents = fixed_contents.gsub(/\n\n+\z/, "\n")

            next unless original_contents != fixed_contents

            # Write the fixed content back to the file
            File.write(file, fixed_contents)
            # Re-stage the file after fixing
            execute(%W[git add #{file}])
            messages << Overcommit::Hook::Message.new(
              :warning,
              file,
              nil,
              'Fixed whitespace issues'
            )
          end

          messages.any? ? messages : :pass
        end
      end
    end
  end
end
