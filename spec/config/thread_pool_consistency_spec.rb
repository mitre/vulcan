# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Thread pool consistency' do
  it 'puma.rb and database.yml use the same RAILS_MAX_THREADS default' do
    puma_rb = Rails.root.join('config/puma.rb').read
    database_yml = Rails.root.join('config/database.yml').read

    puma_default = puma_rb[/ENV\.fetch\(['"]RAILS_MAX_THREADS['"],\s*(\d+)\)/, 1]
    db_default = database_yml[/ENV\.fetch\("RAILS_MAX_THREADS"\)\s*\{\s*(\d+)\s*\}/, 1]

    expect(puma_default).to be_present, 'could not parse RAILS_MAX_THREADS default from puma.rb'
    expect(db_default).to be_present, 'could not parse RAILS_MAX_THREADS default from database.yml'
    expect(db_default).to eq(puma_default),
                          "database.yml default (#{db_default}) != puma.rb default (#{puma_default})"
  end
end
