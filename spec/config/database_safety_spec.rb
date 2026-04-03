# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Database deployment safety', type: :request do
  # These tests prevent regressions in database deployment configuration.
  #
  # BACKGROUND (February 2026):
  # A previous session added DISABLE_DATABASE_ENVIRONMENT_CHECK=1 to
  # bin/docker-entrypoint with db:prepare, believing it was required for
  # Rails 8 production. This was WRONG and dangerous — db:prepare never
  # calls check_protected_environments! (it calls load_schema as a Ruby
  # method, bypassing the rake task protection). The flag is only needed
  # for destructive rake tasks like db:schema:load, db:drop, db:purge.
  #
  # The correct configuration is:
  #   - docker-entrypoint: db:prepare (no flag needed)
  #   - Procfile release:  db:migrate (safe for existing production DBs)
  #   - app.json postdeploy: DISABLE_DATABASE_ENVIRONMENT_CHECK=1 db:schema:load
  #     (review apps always have fresh DBs, flag needed for the rake task)

  let(:entrypoint_raw) { Rails.root.join('bin/docker-entrypoint').read }
  let(:entrypoint_code) { entrypoint_raw.lines.reject { |l| l.strip.start_with?('#') }.join }
  let(:procfile) { Rails.root.join('Procfile').read }
  let(:app_json) { JSON.parse(Rails.root.join('app.json').read) }

  describe 'bin/docker-entrypoint' do
    it 'uses db:prepare for idempotent database setup' do
      expect(entrypoint_code).to include('db:prepare'),
                                 'docker-entrypoint must use db:prepare (handles both fresh and existing DBs)'
    end

    it 'does NOT use DISABLE_DATABASE_ENVIRONMENT_CHECK in executable lines' do
      expect(entrypoint_code).not_to include('DISABLE_DATABASE_ENVIRONMENT_CHECK'),
                                     'docker-entrypoint must NEVER bypass the protected environment check. ' \
                                     'db:prepare does not need it — see Rails DatabaseTasks#initialize_database'
    end

    it 'does NOT use db:schema:load directly in executable lines' do
      expect(entrypoint_code).not_to include('db:schema:load'),
                                     'docker-entrypoint must not call db:schema:load directly. ' \
                                     'Use db:prepare instead.'
    end
  end

  describe 'Procfile' do
    it 'uses db:migrate for Heroku release phase' do
      expect(procfile).to match(/^release:.*db:migrate/),
                          'Procfile release phase must use db:migrate (safe for existing production databases)'
    end

    it 'does NOT use DISABLE_DATABASE_ENVIRONMENT_CHECK' do
      expect(procfile).not_to include('DISABLE_DATABASE_ENVIRONMENT_CHECK'),
                              'Procfile must NEVER bypass the protected environment check'
    end

    it 'does NOT use db:prepare in release phase' do
      release_line = procfile.lines.find { |l| l.start_with?('release:') }
      expect(release_line).not_to include('db:prepare'),
                                  'Procfile release should use db:migrate, not db:prepare. ' \
                                  'Heroku production always has an existing database.'
    end
  end

  describe 'app.json review app postdeploy' do
    let(:postdeploy) { app_json.dig('environments', 'review', 'scripts', 'postdeploy') }
    let(:review_env) { app_json.dig('environments', 'review', 'env') }

    it 'uses db:schema:load for fresh review app databases' do
      expect(postdeploy).to include('db:schema:load'),
                            'Review app postdeploy should use db:schema:load for fresh databases'
    end

    it 'sets DISABLE_DATABASE_ENVIRONMENT_CHECK for the schema:load rake task' do
      expect(postdeploy).to include('DISABLE_DATABASE_ENVIRONMENT_CHECK=1'),
                            'Review apps run with RAILS_ENV=production. The db:schema:load rake task ' \
                            'calls check_protected_environments! and needs the flag to bypass it.'
    end

    it 'runs db:seed to populate review app with test data' do
      expect(postdeploy).to include('db:seed'),
                            'Review app postdeploy should run db:seed for usable test data'
    end

    it 'runs admin:bootstrap to create an admin user' do
      expect(postdeploy).to include('admin:bootstrap'),
                            'Review app postdeploy should run admin:bootstrap so the app is usable'
    end

    it 'enables first-user-admin for review apps' do
      first_user_admin = review_env&.dig('VULCAN_FIRST_USER_ADMIN', 'value')
      expect(first_user_admin).to eq('true'),
                                  'Review apps should enable first-user-admin as a fallback ' \
                                  'for creating an admin via registration'
    end

    it 'provisions a PostgreSQL addon for review apps' do
      addons = app_json.dig('environments', 'review', 'addons')
      expect(addons).to include(a_string_matching(/heroku-postgresql/)),
                        'Review apps must provision their own PostgreSQL database'
    end
  end

  describe 'app.json global env does NOT contain dangerous flags' do
    let(:global_env) { app_json['env'] }

    it 'does NOT set DISABLE_DATABASE_ENVIRONMENT_CHECK globally' do
      expect(global_env.keys).not_to include('DISABLE_DATABASE_ENVIRONMENT_CHECK'),
                                     'DISABLE_DATABASE_ENVIRONMENT_CHECK must NEVER be set globally — ' \
                                     'it would affect production and staging deploys'
    end
  end
end
