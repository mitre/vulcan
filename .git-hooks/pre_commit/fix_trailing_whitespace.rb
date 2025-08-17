module Overcommit::Hook::PreCommit
  # Automatically fixes trailing whitespace in staged files
  class FixTrailingWhitespace < Base
    def run
      messages = []

      applicable_files.each do |file|
        next unless File.exist?(file)

        original_contents = File.read(file)
        # Remove trailing whitespace from each line
        fixed_contents = original_contents.gsub(/[ \t]+$/, '')

        # Remove excessive trailing newlines (keep max 1)
        fixed_contents = fixed_contents.gsub(/\n\n+\z/, "\n")

        if original_contents != fixed_contents
          File.write(file, fixed_contents)
          # Re-stage the file after fixing
          execute(%W[git add #{file}])
          messages << Overcommit::Hook::Message.new(
            :warning,
            file,
            nil,
            "Fixed trailing whitespace"
          )
        end
      end

      messages.any? ? messages : :pass
    end
  end
end