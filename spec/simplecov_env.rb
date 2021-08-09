# frozen_string_literal: true

require 'simplecov'
require 'active_support/core_ext/numeric/time'

module SimpleCovEnv
  module_function

  def start!
    return unless ENV['CI']

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

      merge_timeout 365.days
    end
  end
end
