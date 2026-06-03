# frozen_string_literal: true

namespace :openapi do
  desc 'Run request + contract specs with OpenAPI coverage reporting (single-process only)'
  task coverage: :environment do
    puts '═══ OpenAPI Coverage Report ═══'
    puts ''
    puts 'Running request + contract specs in single-process mode with coverage tracking...'
    puts 'Parallel mode is disabled — each path/operation/status needs to be seen by one process.'
    puts ''

    success = system(
      { 'OPENAPI_COVERAGE' => '1' },
      'bundle', 'exec', 'rspec',
      'spec/requests/', 'spec/contracts/',
      '--format', 'progress',
      '--no-color'
    )

    puts ''
    puts '═══ End Coverage Report ═══'
    puts ''
    puts success ? '  All specs passed.' : '  Some specs failed — see output above.'
    puts '  Coverage report printed above (✓ = covered, ❌ = gap).'
    puts '  To see all paths (including covered): set verbose: true in openapi_contract.rb'

    exit(success ? 0 : 1)
  end
end
