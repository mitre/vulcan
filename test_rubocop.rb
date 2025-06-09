# frozen_string_literal: true

# Test file with Rubocop violations
class TestRubocop
  def bad_method
    puts 'This has trailing whitespace'
    1 + 2 # No spaces around operators
  end
end
