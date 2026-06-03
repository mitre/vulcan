# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'database.yml name isolation' do
  let(:db_config_raw) { Rails.root.join('config/database.yml').read }

  it 'test database name does not read DATABASE_NAME env var' do
    test_section = db_config_raw[/^test:.*?(?=^\w|\z)/m]
    database_line = test_section.lines.find { |l| l.strip.start_with?('database:') }

    expect(database_line).not_to(
      match(/DATABASE_NAME/),
      'test database must NOT use DATABASE_NAME — it collides with development when set'
    )
  end

  it 'development and test have distinct default database names' do
    configs = ActiveRecord::Base.configurations
    dev_db = configs.configs_for(env_name: 'development').first.database
    test_db = configs.configs_for(env_name: 'test').first.database

    expect(dev_db).not_to(
      eq(test_db),
      "dev DB '#{dev_db}' must differ from test DB '#{test_db}'"
    )
  end

  it 'production uses DATABASE_NAME not POSTGRES_DB' do
    prod_section = db_config_raw[/^production:.*?(?=^\w|\z)/m]
    database_line = prod_section.lines.find { |l| l.strip.start_with?('database:') }

    expect(database_line).not_to(
      match(/POSTGRES_DB/),
      'production should use DATABASE_NAME for consistency, not POSTGRES_DB'
    )
    expect(database_line).to(
      match(/DATABASE_NAME/),
      'production database should be configurable via DATABASE_NAME'
    )
  end
end
