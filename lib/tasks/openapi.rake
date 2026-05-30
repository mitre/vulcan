# frozen_string_literal: true

namespace :openapi do
  desc 'Smoke test: validate every GET endpoint returns spec-conformant responses (read-only, no side effects)'
  task :smoke do
    token = create_smoke_token
    run_schemathesis(
      token: token,
      phases: 'examples,coverage',
      max_examples: 1,
      label: 'smoke',
      read_only: true
    )
  end

  desc 'Full CRUD test: disposable Docker environment, all methods, all endpoints (bin/schemathesis-full)'
  task :test do
    exec 'bin/schemathesis-full'
  end

  def create_smoke_token
    require_relative '../../config/environment'
    admin = User.find_by!(email: 'admin@example.com')
    pat = admin.personal_access_tokens.create!(
      name: "schemathesis-#{Time.current.to_i}",
      scopes: %w[read write admin],
      expires_at: 1.day.from_now.to_date
    )
    at_exit do
      pat.revoke! if pat.persisted? && pat.revoked_at.nil?
      admin.unlock_access! if admin.access_locked?
      admin.update_columns(failed_attempts: 0) if admin.failed_attempts.positive?
      PersonalAccessToken.where('name LIKE ?', 'schemathesis-%').find_each(&:revoke!)
    end
    pat.raw_token
  end

  def run_schemathesis(token:, phases:, max_examples:, label:, read_only: true)
    base_url = ENV.fetch('BASE_URL', 'http://localhost:3000')
    spec = File.expand_path('doc/openapi.yaml', Rails.root)

    unless File.exist?(spec)
      abort "ERROR: #{spec} not found. Run: yarn openapi:bundle"
    end

    cmd = [
      'uvx', 'schemathesis', 'run', spec,
      '--url', base_url,
      '--header', "Authorization: Token #{token}",
      '--header', 'Accept: application/json',
      '--checks', 'not_a_server_error,status_code_conformance,content_type_conformance,response_schema_conformance',
      '--exclude-checks', 'negative_data_rejection,ignored_auth',
      '--phases', phases,
      '--max-examples', max_examples.to_s,
      '--rate-limit', '4/s',
      '--exclude-path-regex', '.*/(upload|import_backup|create_from_backup|detect_srg|preview_spreadsheet|apply_spreadsheet|bulk_export).*',
      '--exclude-path-regex', '.*/personal_access_tokens.*',
      '--exclude-deprecated',
      *(read_only ? ['--include-method', 'GET'] : []),
      '--report', 'junit',
      '--report-junit-path', "tmp/schemathesis-#{label}.xml",
      '--suppress-health-check', 'too_slow,large_base_example',
      '--workers', '1'
    ]

    puts "Running Schemathesis #{label} test..."
    puts "  Base URL: #{base_url}"
    puts "  Spec: #{spec}"
    puts "  Phases: #{phases}"
    puts "  Max examples: #{max_examples}"
    puts "  Mode: #{read_only ? 'READ-ONLY (GET only, no side effects)' : 'FULL (includes mutations — will create/modify data)'}"
    puts ''

    system(*cmd) || exit(1)
  end
end
