# frozen_string_literal: true

source 'https://rubygems.org'

ruby '~> 2.7'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.1.4'
# Use postgresql as the database for Active Record
gem 'pg', '>= 0.18', '< 2.0'
# Use Puma as the app server
gem 'puma', '~> 5.6'
# Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker
gem 'webpacker', '~> 5.0'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.7'
# Use HAML instead of ERB
gem 'haml-rails', '~> 2.0'
# Add Devise for authentication
gem 'devise'
# Use Omniauth to support additional login providers
gem 'omniauth', '~> 2.1'
# LDAP Auth
# GitLab fork with several improvements to original library. For full list of changes
# see https://github.com/intridea/omniauth-ldap/compare/master...gitlabhq:master
gem 'gitlab_omniauth-ldap', '~> 2.2.0', require: 'omniauth-ldap'
# Allow users to sign in with GitHub
gem 'omniauth-github'
# https://github.com/omniauth/omniauth/wiki/Resolving-CVE-2015-9284
gem 'omniauth-rails_csrf_protection', '~> 1.0'
# Allow users to sign in with OIDC providers
gem 'omniauth_openid_connect', '~> 0.6.0'
# Vulcan settings
gem 'settingslogic', '~> 2.0.9'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.2', require: false

gem 'audited', '~> 5.3.3'

gem 'activerecord-import'

gem 'ffaker', '~> 2.10'

gem 'nokogiri'
gem 'nokogiri-happymapper'

gem 'amoeba'

# For reading excel files
gem 'fast_excel'
# For writing excel files
gem 'ruh-roo', '~> 3.0.0', require: 'roo'

gem 'ox'

gem 'rubyzip'

gem 'mitre-inspec-objects'
gem 'rest-client'

group :development do
  gem 'listen', '~> 3.1.5'
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'letter_opener'
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  # Process manager for Procfile-based applications (development only)
  gem 'foreman'
end

group :test do
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '>= 2.15'
  gem 'selenium-webdriver'
  # Easy installation and use of web drivers to run system tests with browsers
  # gem 'webdrivers'

  gem 'database_cleaner-active_record'
  gem 'rubocop', require: false
  gem 'rubocop-performance'
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
  gem 'simplecov', require: false
  gem 'webmock'
end

group :development, :test do
  gem 'brakeman'
  gem 'byebug'
  gem 'factory_bot_rails', '~> 5.2.0'
  gem 'rspec-mocks'
  gem 'rspec-rails', '~> 4.0.0'
  # Load environment variables from .env files in development and test
  gem 'dotenv-rails'
end

# Windows and Mac do not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data'

gem 'highline', '~> 2.0'
# Ruby wrapper around slack API
gem 'slack-ruby-client', '1.0.0'
# Slack notification formatting
gem 'slack_block_kit', '0.3.3'
