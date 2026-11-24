# frozen_string_literal: true

# Turns CSRF forgery protection on for specs that exercise the authenticity
# check. config/environments/test.rb disables it suite-wide, so without this
# a request would pass verify_authenticity_token whether or not it carried a
# valid token. The previous value is restored after each example.
#
# Usage:
#   include_context 'with forgery protection'   # at describe/context level
#
RSpec.shared_context 'with forgery protection' do
  around do |example|
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
