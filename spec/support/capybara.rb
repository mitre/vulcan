# frozen_string_literal: true

Capybara.default_driver = ENV['CI'] ? :selenium_chrome_headless : :selenium_chrome
