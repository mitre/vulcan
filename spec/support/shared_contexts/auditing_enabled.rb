# frozen_string_literal: true

# Re-enables auditing for specs that assert on Audited::Audit records.
# Auditing is disabled globally in rails_helper.rb to prevent PostgreSQL
# deadlocks during parallel factory setup (see audited gem issue #410).
#
# Usage:
#   include_context 'with auditing'          # at describe/context level
#
RSpec.shared_context 'with auditing' do
  around do |example|
    Audited.auditing_enabled = true
    example.run
  ensure
    Audited.auditing_enabled = false
  end
end
