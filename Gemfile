# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.4.8'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 8.0.0'
# Use postgresql as the database for Active Record
gem 'pg', '>= 0.18', '< 2.0'
# Use Puma as the app server
gem 'puma', '~> 7.0'
# Asset pipeline for JavaScript bundling
gem 'jsbundling-rails'
# Asset pipeline for Rails
gem 'propshaft'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.7'
# Use HAML instead of ERB
gem 'haml-rails', '~> 2.0'
# Add Devise for authentication
gem 'devise', '~> 4.9'
# PBKDF2-SHA512 password hashing for FIPS 140-2 compliance
gem 'devise-encryptable'
# Session limiting (AC-10), session tracking, and server-side session store
gem 'activerecord-session_store'
gem 'devise-security', github: 'mitre/devise-security', ref: '9f560ed125c096205ba9434de8feea532ce97b4c'
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
# Vulcan settings - upgraded for Ruby 3.1+ compatibility
gem 'mitre-settingslogic', '~> 3.0'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.2', require: false

# Ruby 3.4 compatibility - these will be removed from stdlib
gem 'abbrev'
gem 'csv'

gem 'audited', '~> 5.8.0'

# Advisory locks for preventing race conditions (PostgreSQL/MySQL)
gem 'with_advisory_lock', '~> 5.1'

# Health check endpoints for Kubernetes/Docker probes
gem 'health_check', '~> 3.1'

# PostgreSQL full-text search with trigrams, fuzzy matching, and ranking
gem 'pg_search'

gem 'activerecord-import'

gem 'ffaker', '~> 2.10'

gem 'nokogiri'
gem 'nokogiri-happymapper'

gem 'amoeba'

# For writing excel files with xml:space="preserve" (fixes whitespace round-trip)
gem 'caxlsx'
# For reading excel files
gem 'ruh-roo', '~> 3.0.0', require: 'roo'

# NKF/kconv - removed from default gems in Ruby 3.4+, needed by gitlab_omniauth-ldap
gem 'nkf'

# REXML - required explicitly in Ruby 3.0+
gem 'rexml'

gem 'ox'

gem 'rubyzip'

# Rate limiting and request throttling
gem 'rack-attack'

gem 'mitre-inspec-objects'
gem 'rest-client'

group :development do
  gem 'listen', '~> 3.7'
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  # Letter opener for email previews in development
  gem 'letter_opener'
  # Process manager for Procfile-based applications (development only)
  gem 'foreman'
  # Git hooks management (lefthook installed via brew, not bundled)
  # Security vulnerability scanner for Ruby dependencies
  gem 'bundler-audit', require: false
end

group :test do
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '>= 2.15'
  gem 'selenium-webdriver'
  # Easy installation and use of web drivers to run system tests with browsers
  # gem 'webdrivers'

  gem 'database_cleaner-active_record'
  gem 'rubocop', require: false
  gem 'rubocop-capybara'
  gem 'rubocop-factory_bot'
  gem 'rubocop-performance'
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
  gem 'rubocop-rspec_rails'
  gem 'shoulda-matchers', '~> 7.0'
  gem 'simplecov', require: false
  gem 'test-prof', '~> 1.5'
  gem 'webmock'
end

group :development, :test do
  gem 'brakeman'
  gem 'byebug'
  gem 'factory_bot_rails', '~> 6.5.0'
  gem 'parallel_tests'
  gem 'rspec-mocks'
  gem 'rspec-rails', '~> 6.0'
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
