# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Thread pool consistency' do
  it 'puma.rb and database.yml use the same RAILS_MAX_THREADS default' do
    puma_rb = Rails.root.join('config/puma.rb').read
    database_yml = Rails.root.join('config/database.yml').read

    puma_default = puma_rb[/ENV\.fetch\(['"]RAILS_MAX_THREADS['"],\s*(\d+)\)/, 1]
    db_default = database_yml[/ENV\.fetch\(['"]RAILS_MAX_THREADS['"],\s*(\d+)\)/, 1] ||
                 database_yml[/ENV\.fetch\(['"]RAILS_MAX_THREADS['"]\)\s*\{\s*(\d+)\s*\}/, 1]

    expect(puma_default).to be_present, 'could not parse RAILS_MAX_THREADS default from puma.rb'
    expect(db_default).to be_present, 'could not parse RAILS_MAX_THREADS default from database.yml'
    expect(db_default).to eq(puma_default),
                          "database.yml default (#{db_default}) != puma.rb default (#{puma_default})"
  end

  # The equality example above cannot catch a change to the number itself:
  # both files moving together still passes, which is how
  # ENVIRONMENT_VARIABLES.md came to document 10 while the code shipped 3.
  # Pinning the value makes a deliberate change a deliberate edit here, and
  # the documentation check in env_documentation_consistency_spec then reads
  # the number out of the code rather than hardcoding it again.
  it 'defaults RAILS_MAX_THREADS to 3' do
    puma_default = Rails.root.join('config/puma.rb')
                        .read[/ENV\.fetch\(['"]RAILS_MAX_THREADS['"],\s*(\d+)\)/, 1]

    expect(puma_default).to eq('3'),
                            'the documented RAILS_MAX_THREADS default is 3, but puma.rb ships ' \
                            "#{puma_default.inspect}. If this is intentional, update " \
                            'ENVIRONMENT_VARIABLES.md and this example together.'
  end
end
