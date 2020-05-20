# frozen_string_literal: true

require 'simplecov'
require 'active_support/core_ext/numeric/time'

module SimpleCovEnv
  extend self

  def start!
    return unless ENV['CI']

    configure_profile

    SimpleCov.start
  end

  def configure_profile
    SimpleCov.configure do
      load_profile 'test_frameworks'
      track_files '{app,lib}/**/*.rb'

      add_filter '/vendor/ruby/'
      add_filter 'config/initializers/'
      add_filter 'db/fixtures/'

      add_group 'Controllers', 'app/controllers'
      # add_group 'Finders',     'app/finders'
      add_group 'Helpers',     'app/helpers'
      # add_group 'Libraries',   'lib'
      add_group 'Mailers',     'app/mailers'
      add_group 'Models',      'app/models'
      # add_group 'Policies',    'app/policies'
      # add_group 'Presenters',  'app/presenters'
      # add_group 'Serializers', 'app/serializers'
      # add_group 'Services',    'app/services'
      # add_group 'Uploaders',   'app/uploaders'
      # add_group 'Validators',  'app/validators'
      # add_group 'Workers',     %w(app/jobs app/workers)

      merge_timeout 365.days
    end
  end
end
