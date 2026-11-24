# frozen_string_literal: true

require 'simplecov'

module SimpleCovEnv
  module_function

  # CI always measures coverage. COVERAGE=1 asks for it locally without the
  # rest of what CI=true implies (eager loading, headless Capybara, the LDAP
  # system spec being skipped), which is what the docs have always documented.
  def start!
    return unless ENV['CI'] || ENV['COVERAGE']

    configure_profile

    SimpleCov.start
    SimpleCov.minimum_coverage 0
  end

  def configure_profile
    SimpleCov.configure do
      load_profile 'test_frameworks'
      track_files '{app,lib}/**/*.rb'

      add_filter '/vendor/ruby/'
      add_filter 'config/initializers/'
      add_filter 'db/fixtures/'

      add_group 'Controllers', 'app/controllers'
      add_group 'Helpers',     'app/helpers'
      add_group 'Mailers',     'app/mailers'
      add_group 'Models',      'app/models'

      merge_timeout 365 * 24 * 60 * 60 # 365 days in seconds
    end
  end
end
