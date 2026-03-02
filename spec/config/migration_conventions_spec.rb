# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'migration file conventions' do
  # REQUIREMENT: All migration files must include the frozen_string_literal
  # magic comment for consistency with project convention.

  it 'all migrations have frozen_string_literal: true' do
    migrations = Rails.root.glob('db/migrate/*.rb')
    missing = migrations.reject do |f|
      f.read.start_with?('# frozen_string_literal: true')
    end

    expect(missing).to be_empty,
                       "Migrations missing frozen_string_literal:\n#{missing.map(&:basename).join("\n")}"
  end
end
