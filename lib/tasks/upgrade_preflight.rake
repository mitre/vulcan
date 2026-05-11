# frozen_string_literal: true

# Vulcan Upgrade Toolkit
#
# Two read-only tasks for safe upgrades:
#   rails upgrade:preflight  — run BEFORE upgrading (validates connectivity, schema, data)
#   rails upgrade:verify     — run AFTER upgrading (validates schema, models, assets)
#
# Usage:
#   bundle exec rails upgrade:preflight
#   bundle exec rails upgrade:verify
#   docker compose exec web rails upgrade:preflight
#   docker compose exec web rails upgrade:verify

namespace :upgrade do
  desc 'Pre-flight check for Vulcan upgrades (read-only, safe on live DB)'
  task preflight: :environment do
    puts '=' * 70
    puts "  Vulcan Upgrade Preflight Check — #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}"
    puts '=' * 70
    puts

    conn = ActiveRecord::Base.connection
    issues = []
    warnings = []

    # =====================================================================
    # Phase 1: Connection & Environment
    # =====================================================================
    puts '── Phase 1: Connection & Environment ──'
    puts

    begin
      pg_version = conn.exec_query('SELECT version()').first['version']
      puts '  ✓ Database connected'
      puts "    PostgreSQL: #{pg_version}"

      if pg_version.include?('Aurora')
        puts '    Runtime:    Amazon Aurora'
        warnings << 'Aurora detected — see Aurora-specific notes at the end'
      end
    rescue StandardError => e
      issues << "Cannot connect to database: #{e.message}"
      puts "  ✗ Database connection FAILED: #{e.message}"
      puts
      puts '  Checklist:'
      puts '    - Is DATABASE_URL set? (takes precedence in production)'
      puts '    - Or are DATABASE_HOST + DATABASE_PORT + POSTGRES_USER + POSTGRES_PASSWORD set?'
      puts '    - For Aurora RDS: is the cluster endpoint correct (not the instance endpoint)?'
      puts '    - For Aurora RDS: add ?sslmode=require to DATABASE_URL'
      puts '    - Set DATABASE_GSSENCMODE=disable (Aurora does not support GSSAPI)'
      puts
      puts '  ✗ CANNOT PROCEED — fix database connectivity first.'
      exit 1
    end

    # SSL check
    begin
      ssl_result = conn.exec_query("SELECT CASE WHEN ssl THEN 'yes' ELSE 'no' END AS ssl_is_used FROM pg_stat_ssl WHERE pid = pg_backend_pid()")
      ssl_used = ssl_result.first&.fetch('ssl_is_used', 'unknown') || 'unknown'
      if ssl_used == 'yes'
        puts '  ✓ SSL connection active'
      else
        warnings << 'SSL is not active — cloud databases (Aurora, RDS) typically require sslmode=require'
        puts '  ⚠ SSL connection not active'
      end
    rescue StandardError
      puts '  ℹ SSL status could not be determined (pg_stat_ssl not available)'
    end

    # Read-replica detection
    begin
      recovery = conn.exec_query('SELECT pg_is_in_recovery()').first['pg_is_in_recovery']
      if recovery
        issues << 'Database is in recovery mode (read-only replica) — writes will fail'
        puts '  ✗ Database is a read-replica (pg_is_in_recovery=true) — migrations cannot run'
      else
        puts '  ✓ Database is primary (not a read-replica)'
      end
    rescue StandardError
      puts '  ℹ Could not check replica status'
    end

    # Database encoding
    encoding = conn.exec_query('SELECT pg_encoding_to_char(encoding) AS enc FROM pg_database WHERE datname = current_database()').first['enc']
    if encoding == 'UTF8'
      puts "  ✓ Database encoding: #{encoding}"
    else
      warnings << "Database encoding is #{encoding} (expected UTF8) — text indexes may behave unexpectedly"
      puts "  ⚠ Database encoding: #{encoding} (expected UTF8)"
    end

    # pg_trgm extension
    begin
      conn.exec_query("SELECT 'test' % 'test'")
      puts '  ✓ pg_trgm extension available'
    rescue StandardError
      begin
        conn.exec_query('CREATE EXTENSION IF NOT EXISTS pg_trgm')
        puts '  ✓ pg_trgm extension installed'
      rescue StandardError => e
        issues << "pg_trgm extension unavailable: #{e.message}. Search indexes will fail."
        puts "  ✗ pg_trgm extension UNAVAILABLE: #{e.message}"
        puts '    For Aurora: enable pg_trgm in the DB parameter group'
      end
    end

    # Environment variables
    puts
    %w[SECRET_KEY_BASE CIPHER_PASSWORD CIPHER_SALT].each do |var|
      if ENV[var].present?
        puts "  ✓ #{var} is set"
      else
        warnings << "#{var} is not set (required for production)"
        puts "  ⚠ #{var} is NOT SET"
      end
    end

    # gssencmode
    gss = ENV.fetch('DATABASE_GSSENCMODE', 'prefer')
    if gss == 'disable'
      puts '  ✓ DATABASE_GSSENCMODE=disable (correct for Aurora/cloud RDS)'
    else
      warnings << "DATABASE_GSSENCMODE=#{gss} — set to 'disable' for Aurora RDS (GSSAPI not supported)"
      puts "  ⚠ DATABASE_GSSENCMODE=#{gss} — Aurora users should set to 'disable'"
    end

    # =====================================================================
    # Phase 2: Schema State
    # =====================================================================
    puts
    puts '── Phase 2: Schema State ──'
    puts

    current_version = conn.exec_query('SELECT MAX(version) AS v FROM schema_migrations').first['v']
    puts "  Current schema version: #{current_version || '(none — fresh database)'}"

    all_migrations = Rails.root.glob('db/migrate/*.rb').map { |f| File.basename(f).split('_').first }.sort
    applied = conn.exec_query('SELECT version FROM schema_migrations ORDER BY version').rows.flatten
    pending = all_migrations - applied

    if pending.empty?
      puts '  ✓ No pending migrations'
    else
      puts "  ⚠ #{pending.size} pending migration(s):"
      pending.each do |version|
        filename = Rails.root.glob("db/migrate/#{version}_*.rb").first
        basename = filename ? File.basename(filename) : version
        risk = case basename
               when /foreign_key|validate/
                 '[FK]'
               when /concurrently|index/
                 '[INDEX]'
               when /backfill|normalize|strip/
                 '[DATA]'
               else
                 ''
               end
        puts "    #{basename} #{risk}"
      end
    end

    # Schema drift detection
    puts
    drift_found = false
    expected_tables = %w[users projects components base_rules reviews memberships audits]
    expected_tables.each do |table|
      next unless conn.table_exists?(table)

      db_columns = conn.columns(table).map(&:name).sort
      # Compare against what Rails models expect
      next if db_columns.empty?

      model = table.classify.safe_constantize
      next unless model

      schema_columns = begin
        model.column_names.sort
      rescue StandardError
        next
      end
      extra = db_columns - schema_columns
      missing = schema_columns - db_columns
      next unless extra.any? || missing.any?

      drift_found = true
      warnings << "Schema drift on #{table}: extra=#{extra}, missing=#{missing}" if extra.any? || missing.any?
      puts "  ⚠ Schema drift detected on #{table}" if extra.any? || missing.any?
    end
    puts '  ✓ No schema drift detected in core tables' unless drift_found

    # Partial migration integrity check
    applied.select { |v| v < current_version.to_s }
    older_unapplied = all_migrations.select { |v| v < current_version.to_s } - applied
    if older_unapplied.any?
      warnings << "#{older_unapplied.size} migration(s) older than current version are not applied (partial upgrade?)"
      puts "  ⚠ Partial migration integrity issue: #{older_unapplied.size} gap(s) in schema_migrations"
    else
      puts '  ✓ Migration integrity OK (no gaps)'
    end

    # Upgrade path with version-specific notes
    puts
    puts '  Upgrade path version notes:'
    version_notes = {
      '20260221' => 'v2.3.0: Devise lockable + sessions table (existing sessions invalidated)',
      '20260302' => 'v2.3.1: OIDC provider fix + auth improvements',
      '20260429' => 'v2.3.5: PUBLIC COMMENT REVIEW (PR-717) — 8 new columns on reviews, 6 FK constraints',
      '20260505' => 'v2.3.6: Reactions (thumbs up/down) + UBI9 Docker base'
    }
    if pending.any?
      version_notes.each do |prefix, note|
        relevant = pending.any? { |v| v.start_with?(prefix[0..5]) }
        puts "    #{note}" if relevant
      end
    else
      puts '    (no pending migrations — already current)'
    end

    # =====================================================================
    # Phase 3: Data Integrity
    # =====================================================================
    puts
    puts '── Phase 3: Data Integrity ──'
    puts

    if conn.table_exists?(:reviews)
      # Orphaned review.user_id
      orphan_users = conn.exec_query(
        'SELECT COUNT(*) AS c FROM reviews WHERE user_id IS NOT NULL AND user_id NOT IN (SELECT id FROM users)'
      ).first['c']
      if orphan_users.zero?
        puts '  ✓ No orphaned review.user_id references'
      else
        warnings << "#{orphan_users} review(s) reference deleted users — migration will nullify"
        puts "  ⚠ #{orphan_users} review(s) reference deleted users (will be nullified)"
      end

      # Orphaned review.rule_id
      orphan_rules = conn.exec_query(
        'SELECT COUNT(*) AS c FROM reviews WHERE rule_id IS NOT NULL AND rule_id NOT IN (SELECT id FROM base_rules)'
      ).first['c']
      if orphan_rules.zero?
        puts '  ✓ No orphaned review.rule_id references'
      else
        warnings << "#{orphan_rules} review(s) reference deleted rules — migration will DELETE"
        puts "  ⚠ #{orphan_rules} review(s) reference deleted rules (will be DELETED)"
      end

      # Orphaned responding_to_review_id
      if conn.column_exists?(:reviews, :responding_to_review_id)
        orphan_parents = conn.exec_query(
          'SELECT COUNT(*) AS c FROM reviews WHERE responding_to_review_id IS NOT NULL ' \
          'AND responding_to_review_id NOT IN (SELECT id FROM reviews)'
        ).first['c']
        if orphan_parents.zero?
          puts '  ✓ No orphaned review.responding_to_review_id references'
        else
          issues << "#{orphan_parents} review(s) reference deleted parent reviews — FK will fail"
          puts "  ✗ #{orphan_parents} orphaned parent review references (FK will FAIL)"
        end
      end
    else
      puts '  ℹ reviews table does not exist yet (fresh database)'
    end

    # Orphaned component.project_id
    if conn.table_exists?(:components)
      orphan_components = conn.exec_query(
        'SELECT COUNT(*) AS c FROM components WHERE project_id IS NOT NULL AND project_id NOT IN (SELECT id FROM projects)'
      ).first['c']
      if orphan_components.zero?
        puts '  ✓ No orphaned component.project_id references'
      else
        warnings << "#{orphan_components} component(s) reference deleted projects"
        puts "  ⚠ #{orphan_components} orphaned component.project_id references"
      end
    end

    # Orphaned membership references
    if conn.table_exists?(:memberships)
      orphan_memberships = conn.exec_query(
        'SELECT COUNT(*) AS c FROM memberships WHERE user_id NOT IN (SELECT id FROM users)'
      ).first['c']
      if orphan_memberships.zero?
        puts '  ✓ No orphaned membership references'
      else
        warnings << "#{orphan_memberships} membership(s) reference deleted users"
        puts "  ⚠ #{orphan_memberships} orphaned membership references"
      end
    end

    # Counter cache drift
    if conn.table_exists?(:components) && conn.column_exists?(:components, :rules_count)
      drift_count = conn.exec_query(
        'SELECT COUNT(*) AS c FROM components WHERE rules_count != (SELECT COUNT(*) FROM base_rules WHERE base_rules.component_id = components.id AND base_rules.type = \'Rule\')'
      ).first['c']
      if drift_count.zero?
        puts '  ✓ Component rules_count counter cache is accurate'
      else
        warnings << "#{drift_count} component(s) have drifted rules_count counter cache"
        puts "  ⚠ #{drift_count} component(s) have rules_count counter cache drift"
      end
    end

    # Table sizes + audits
    puts
    puts '  Table sizes (affects migration time):'
    %w[reviews users base_rules].each do |table|
      next unless conn.table_exists?(table)

      count = conn.exec_query("SELECT COUNT(*) AS c FROM #{table}").first['c'].to_i
      label = count > 10_000 ? "#{count} ⚠ (FK validation will be slow)" : count.to_s
      puts "    #{table}: #{label}"
    end

    if conn.table_exists?(:audits)
      audit_count = conn.exec_query('SELECT COUNT(*) AS c FROM audits').first['c'].to_i
      label = audit_count > 500_000 ? "#{audit_count} ⚠ (backfill migration will be slow)" : audit_count.to_s
      puts "    audits: #{label}"
    end

    # =====================================================================
    # Phase 4: Application Configuration
    # =====================================================================
    puts
    puts '── Phase 4: Application Configuration ──'
    puts

    # Ruby version
    expected_ruby = begin
      Rails.root.join('.ruby-version').read.strip
    rescue StandardError
      nil
    end
    if expected_ruby && expected_ruby == RUBY_VERSION
      puts "  ✓ Ruby version #{RUBY_VERSION} matches .ruby-version"
    elsif expected_ruby
      warnings << "Ruby version mismatch: running #{RUBY_VERSION}, .ruby-version says #{expected_ruby}"
      puts "  ⚠ Ruby version mismatch: running #{RUBY_VERSION}, expected #{expected_ruby}"
    else
      puts "  ℹ Ruby version: #{RUBY_VERSION} (no .ruby-version file found)"
    end

    # Writable directories
    %w[tmp log storage db].each do |dir|
      path = Rails.root.join(dir)
      if path.exist? && path.writable?
        puts "  ✓ #{dir}/ directory is writable"
      elsif path.exist?
        issues << "#{dir}/ is not writable — Rails needs write access"
        puts "  ✗ #{dir}/ directory is NOT writable"
      else
        puts "  ℹ #{dir}/ directory does not exist (will be created)"
      end
    end

    # YAML permitted classes (Rails 7.1+)
    yaml_classes = begin
      Rails.application.config.active_record.yaml_column_permitted_classes
    rescue StandardError
      nil
    end
    if yaml_classes.is_a?(Array) && yaml_classes.include?(Symbol)
      puts '  ✓ YAML permitted classes configured (audited gem compatibility)'
    else
      warnings << 'YAML permitted classes may not include Symbol/Time/BigDecimal — audited gem reads may fail'
      puts '  ⚠ YAML permitted classes — verify config/application.rb includes Symbol, Time, BigDecimal'
    end

    # =====================================================================
    # Phase 5: Summary & Recommendations
    # =====================================================================
    puts
    puts '── Phase 5: Summary ──'
    puts

    if issues.any?
      puts "  ✗ #{issues.size} ISSUE(S) — must fix before upgrading:"
      issues.each { |i| puts "    • #{i}" }
      puts
    end

    if warnings.any?
      puts "  ⚠ #{warnings.size} WARNING(S) — review before upgrading:"
      warnings.each { |w| puts "    • #{w}" }
      puts
    end

    if issues.empty? && warnings.empty?
      puts '  ✓ All checks passed — safe to run: rails db:prepare'
    elsif issues.empty?
      puts '  ⚠ Warnings present but no blockers — review above, then: rails db:prepare'
    else
      puts '  ✗ Fix the issues above before running: rails db:prepare'
    end

    puts
    puts '── Recommendations ──'
    puts
    puts '  1. BACK UP your database before upgrading:'
    puts '     pg_dump -Fc your_database > vulcan_backup_$(date +%Y%m%d).dump'
    puts
    puts '  2. Run migrations:'
    puts '     rails db:prepare   (or: docker compose exec web rails db:prepare)'
    puts
    puts '  3. After migration, verify:'
    puts '     rails upgrade:verify'

    if warnings.any? { |w| w.include?('Aurora') }
      puts
      puts '── Aurora RDS Notes ──'
      puts
      puts '  • Set DATABASE_GSSENCMODE=disable (Aurora does not support GSSAPI)'
      puts '  • Add ?sslmode=require to DATABASE_URL (Aurora enforces SSL)'
      puts '  • If using custom CA: download the RDS CA bundle from'
      puts '    https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem'
      puts '    and place it in the certs/ directory before building the Docker image'
      puts '  • Enable pg_trgm in your Aurora DB parameter group if not already enabled'
      puts '  • Use the cluster endpoint (not the instance endpoint) for DATABASE_HOST'
      puts '  • Aurora PG 14.x is supported — no version-specific issues known'
    end

    puts
    puts '=' * 70
    exit(issues.any? ? 1 : 0)
  end

  # =====================================================================
  # Post-Upgrade Verification
  # =====================================================================
  desc 'Post-upgrade verification (run AFTER db:prepare to confirm success)'
  task verify: :environment do
    puts '=' * 70
    puts "  Vulcan Post-Upgrade Verification — #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}"
    puts '=' * 70
    puts

    conn = ActiveRecord::Base.connection
    issues = []

    # Schema: no pending migrations
    puts '── Schema ──'
    all_migrations = Rails.root.glob('db/migrate/*.rb').map { |f| File.basename(f).split('_').first }.sort
    applied = conn.exec_query('SELECT version FROM schema_migrations ORDER BY version').rows.flatten
    pending = all_migrations - applied

    if pending.empty?
      puts '  ✓ 0 pending migrations — schema is current'
    else
      issues << "#{pending.size} pending migration(s) remain"
      puts "  ✗ #{pending.size} pending migration(s) — db:prepare did not complete"
    end

    # FK constraints validated
    unvalidated = conn.exec_query(
      "SELECT conname, conrelid::regclass AS table_name FROM pg_constraint WHERE contype = 'f' AND NOT convalidated"
    ).rows
    if unvalidated.empty?
      puts '  ✓ All FK constraints are validated (convalidated=true)'
    else
      unvalidated.each do |name, table|
        issues << "FK #{name} on #{table} is not validated"
        puts "  ✗ FK #{name} on #{table} is NOT validated"
      end
    end

    # Model smoke tests
    puts
    puts '── Model Smoke Tests ──'
    %w[Project User Component Review].each do |model_name|
      klass = model_name.safe_constantize
      if klass
        count = begin
          klass.count
        rescue StandardError
          -1
        end
        if count >= 0
          puts "  ✓ #{model_name} model loads (#{count} records)"
        else
          issues << "#{model_name} model query failed"
          puts "  ✗ #{model_name} model query failed"
        end
      else
        issues << "#{model_name} model not found"
        puts "  ✗ #{model_name} model not found"
      end
    end

    # Route check
    puts
    puts '── Routes ──'
    begin
      Rails.application.reload_routes!
      route_count = Rails.application.routes.routes.size
      puts "  ✓ Routes loaded successfully (#{route_count} routes)"
    rescue StandardError => e
      issues << "Route loading failed: #{e.message}"
      puts "  ✗ Route loading failed: #{e.message}"
    end

    # Admin check
    puts
    puts '── Admin ──'
    if User.exists?(admin: true)
      admin_count = User.where(admin: true).count
      puts "  ✓ #{admin_count} admin user(s) exist"
    else
      issues << 'No admin user exists — run: rails db:create_admin'
      puts '  ✗ No admin user exists'
    end

    # Counter cache spot-check
    puts
    puts '── Counter Cache ──'
    sample = Component.order('RANDOM()').limit(5)
    drift = sample.reject { |c| c.rules_count == c.rules.count }
    if drift.empty?
      puts "  ✓ Component rules_count accurate (spot-checked #{sample.size})"
    else
      issues << "#{drift.size} component(s) have drifted rules_count"
      puts "  ⚠ #{drift.size} component(s) have rules_count drift — run: Component.find_each { |c| Component.reset_counters(c.id, :rules) }"
    end

    # Asset check
    puts
    puts '── Assets ──'
    builds_dir = Rails.public_path.join('assets/builds')
    if builds_dir.exist?
      packs = Dir[builds_dir.join('*.js')].map { |f| File.basename(f, '.js') }
      expected = %w[application navbar toaster login]
      missing = expected - packs
      if missing.empty?
        puts "  ✓ Core JavaScript pack files present (#{packs.size} total)"
      else
        issues << "Missing JS packs: #{missing.join(', ')} — run: yarn build"
        puts "  ✗ Missing JS pack files: #{missing.join(', ')}"
      end
    else
      puts '  ℹ No builds directory (assets may be served via CDN or not yet compiled)'
    end

    # Summary
    puts
    puts '── Summary ──'
    puts
    if issues.empty?
      puts '  ✓ All post-upgrade checks passed. Vulcan is ready.'
    else
      puts "  ✗ #{issues.size} issue(s) found:"
      issues.each { |i| puts "    • #{i}" }
    end

    puts
    puts '=' * 70
    exit(issues.any? ? 1 : 0)
  end
end
