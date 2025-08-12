# frozen_string_literal: true

require_relative 'boot'

# Fix for Rails 6.1 compatibility with Ruby 3.1+
# Rails 6.1 expects Logger to be available without requiring it
# In Ruby 3.1+, Logger is no longer autoloaded
# This can be removed after upgrading to Rails 7
require 'logger' if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.1.0')

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_mailbox/engine'
require 'action_text/engine'
require 'action_view/railtie'
require 'action_cable/engine'
# require "sprockets/railtie"
require 'rails/test_unit/railtie'

# Require rexml for SRG parsing
require 'rexml/rexml'

# Require csv for CSV export
require 'csv'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Load dotenv files before initializing Settings
Dotenv.load('.env', ".env.#{Rails.env}", ".env.#{Rails.env}.local") if defined?(Dotenv)

module VulcanVue
  # This application was originally generated using Rails 6.0. Any subsequent updates
  # will require testing to verify that the defaults for that new version do not break
  # any functionality.
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0
    config.time_zone = 'UTC'

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end
