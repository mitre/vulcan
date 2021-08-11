# frozen_string_literal: true

# Raised when a Rule cannot be successfully rolled back to a previous state
class NotAuthorizedError < StandardError
  def initialize(message = 'You are not authorized to perform this action.')
    super message
  end
end
