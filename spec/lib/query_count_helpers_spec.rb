# frozen_string_literal: true

require 'rails_helper'

# The counter's exclusions decide what an invariance assertion can see, so
# they are pinned here with synthetic notifications — no database, no
# request, no timing.
RSpec.describe QueryCountHelpers do
  include described_class

  def fire(name)
    ActiveSupport::Notifications.instrument('sql.active_record', name: name, sql: 'SELECT 1')
  end

  it 'counts ordinary application queries by name' do
    report = count_queries do
      fire('Component Load')
      fire('Component Load')
      fire('Check Delete All')
    end

    expect(report.total).to eq(3)
    expect(report.by_name).to eq('Component Load' => 2, 'Check Delete All' => 1)
  end

  it 'does not count rack-session persistence' do
    # Session rows are written per request, and only when the payload changed
    # that request — timing, not the measured code path, decides whether one
    # lands inside a counted window.
    report = count_queries do
      fire('ActiveRecord::SessionStore::Session Update')
      fire('ActiveRecord::SessionStore::Session Load')
      fire('Component Load')
    end

    expect(report.total).to eq(1)
    expect(report.by_name).to eq('Component Load' => 1)
  end
end
