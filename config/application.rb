# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module VulcanVue
  # Main Rails application configuration for Vulcan
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks vulcan])

    # YAML serialization permitted classes — affects Psych safe-dump used by
    # Rails 7+ for serialized columns. The audited gem stores audited_changes
    # as a YAML hash, so any datetime attribute that flows into an audit
    # (e.g. comment_period_starts_at / comment_period_ends_at on Component)
    # needs its class allowlisted or the dump throws Psych::DisallowedClass.
    #
    # ActiveSupport::TimeWithZone is the canonical Rails wall-clock type;
    # Date/Time/BigDecimal are the other commonly-serialized scalars.
    config.active_record.yaml_column_permitted_classes = [
      Symbol, Date, Time, BigDecimal,
      ActiveSupport::TimeWithZone, ActiveSupport::TimeZone,
      ActiveSupport::HashWithIndifferentAccess
    ]

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
