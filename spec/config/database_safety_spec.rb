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

    it 'does NOT suppress upgrade:auto exit codes' do
      upgrade_lines = entrypoint_code.lines.select { |l| l.include?('upgrade:auto') }
      upgrade_lines.each do |line|
        expect(line).not_to(
          match(/\|\|\s*true/),
          'upgrade:auto must NOT be followed by || true — blockers and errors must halt boot'
        )
        expect(line).not_to(
          include('2>/dev/null'),
          'upgrade:auto must NOT redirect stderr — errors must be visible in container logs'
        )
      end
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

  # The dev database container and Rails must agree on the host port, or the
  # documented "Recommended" setup path fails: docker-compose.dev.yml published
  # ${POSTGRES_PORT:-5435} while config/database.yml read DATABASE_PORT
  # (default 5432), two structurally uncoupled names. Both documented entry
  # points — setup.md Option A and bin/setup — then aborted on db:prepare, and
  # the Compose healthcheck gave a false green because pg_isready runs inside
  # the container.
  #
  # The invariant is one variable, not two values that happen to match: the
  # port Rails dials and the host port the container publishes are the same
  # port by definition.
  describe 'development database port' do
    let(:dev_compose) { Rails.root.join('docker-compose.dev.yml').read }
    let(:database_yml) { Rails.root.join('config/database.yml').read }

    it 'database.yml reads DATABASE_PORT with the standard PostgreSQL default' do
      expect(database_yml).to match(/ENV\.fetch\(['"]DATABASE_PORT['"],\s*5432\)/),
                              'config/database.yml must read DATABASE_PORT defaulting to 5432'
    end

    it 'the dev compose file publishes the database on the same variable and default' do
      published = dev_compose.match(/^\s*-\s*"\$\{(\w+):-(\d+)\}:5432"/)&.captures

      expect(published).to eq(%w[DATABASE_PORT 5432]),
                           'docker-compose.dev.yml must publish the db service on ' \
                           '"${DATABASE_PORT:-5432}:5432" so the container lands on the port ' \
                           "config/database.yml connects to. Found: #{published.inspect}"
    end

    it 'no second name for the same port survives anywhere' do
      offenders = %w[
        docker-compose.dev.yml docker-compose.yml .env.example .env.production.example
        ENVIRONMENT_VARIABLES.md docs/site/development/setup.md
      ].select { |path| Rails.root.join(path).read.include?('POSTGRES_PORT=') }

      expect(offenders).to eq([]),
                           'POSTGRES_PORT was a duplicate name for DATABASE_PORT and is removed; ' \
                           "these files still set it:\n#{offenders.join("\n")}"
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
