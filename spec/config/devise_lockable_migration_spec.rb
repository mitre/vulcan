# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Devise Lockable migration' do
  # schema.rb has failed_attempts, unlock_token, locked_at on users table
  # but no migration file exists. Existing deployments using db:migrate
  # won't get these columns without a proper migration.

  it 'User model has failed_attempts column' do
    expect(User.column_names).to include('failed_attempts')
  end

  it 'User model has unlock_token column' do
    expect(User.column_names).to include('unlock_token')
  end

  it 'User model has locked_at column' do
    expect(User.column_names).to include('locked_at')
  end

  it 'a migration file exists for lockable columns' do
    migration_files = Rails.root.glob('db/migrate/*lockable*')
    expect(migration_files).not_to be_empty,
                                   'Missing migration for Devise Lockable columns (schema.rb has them but no migration)'
  end
end
