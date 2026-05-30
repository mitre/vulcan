# frozen_string_literal: true

require 'json'

# Walks a JSON Archive backup, summarizing structure/depth and scanning for
# real PII (names, non-synthetic emails) across every review identity field
# and the free-text comment body. Used to verify a backup is safe to bake
# into the committed seed pipeline as reproducible test-bed data.
class BackupAuditor
  Finding = Struct.new(:component, :external_id, :field, :value)

  # Email pattern used for PII scanning. Anything not on an allow-listed
  # synthetic domain is flagged as a potential real-PII leak.
  EMAIL_RE = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i
  ALLOWED_EMAIL_DOMAINS = %w[example.com example.org example.net].freeze

  # Review fields that may carry author/triager/adjudicator identity.
  IDENTITY_FIELDS = %w[
    user_name user_email
    triage_set_by_name triage_set_by_email
    adjudicated_by_name adjudicated_by_email
  ].freeze

  # Synthetic demo identities that are safe by construction — not real PII.
  # A name field matching one of these is not flagged.
  ALLOWED_NAMES = [
    'Demo Admin', 'Demo Viewer', 'Demo Author', 'Demo Reviewer',
    'Container Platform Maintainer', 'Photon OS Maintainer',
    'vCenter Maintainer', 'QA Test Maintainer'
  ].freeze

  def initialize(path)
    @path = path
    @components = []
    @pii = []
  end

  def run
    @project = load_json(File.join(@path, 'project.json')) || {}
    Dir.glob(File.join(@path, 'components', '*')).select { |d| File.directory?(d) }.sort.each do |dir|
      audit_component(dir)
    end
    self
  end

  def clean?
    @pii.empty?
  end

  def print_summary
    puts "\n=== JSON Archive Audit: #{@path} ==="
    puts "Project: #{@project['name'] || '(unnamed)'}"
    @components.each do |c|
      puts "\nComponent: #{c[:name]}  (#{c[:rule_count]} rules, #{c[:review_count]} reviews)"
      puts "  triage_status: #{c[:triage].sort_by { |_, v| -v }.to_h}"
      puts "  threaded replies: #{c[:replies]}  | duplicate links: #{c[:duplicates]}  | adjudicated: #{c[:adjudicated]}"
    end

    puts "\n=== PII scan ==="
    if @pii.empty?
      puts '  CLEAN — no real names or non-synthetic emails found.'
    else
      puts "  #{@pii.size} potential PII finding(s):"
      @pii.first(40).each do |f|
        puts "    [#{f.component} ##{f.external_id}] #{f.field} = #{f.value.inspect}"
      end
      puts "    ... (#{@pii.size - 40} more)" if @pii.size > 40
    end
  end

  private

  def audit_component(dir)
    name = File.basename(dir)
    rules = load_json(File.join(dir, 'rules.json')) || []
    reviews = load_json(File.join(dir, 'reviews.json')) || []

    triage = Hash.new(0)
    replies = duplicates = adjudicated = 0

    reviews.each do |r|
      triage[r['triage_status'] || '(untriaged)'] += 1
      replies += 1 if r['responding_to_external_id']
      duplicates += 1 if r['duplicate_of_external_id']
      adjudicated += 1 if r['adjudicated_at']
      scan_pii(name, r)
    end

    @components << {
      name: name, rule_count: rules.size, review_count: reviews.size,
      triage: triage, replies: replies, duplicates: duplicates, adjudicated: adjudicated
    }
  end

  def scan_pii(component, review)
    IDENTITY_FIELDS.each do |field|
      val = review[field].to_s.strip
      next if val.empty?

      if field.end_with?('_email')
        flag(component, review, field, val) unless allowed_email?(val)
      else
        # Flag any non-empty name that isn't a known synthetic demo identity.
        flag(component, review, field, val) unless ALLOWED_NAMES.include?(val)
      end
    end

    # Scan free-text comment for embedded emails on non-synthetic domains.
    review['comment'].to_s.scan(EMAIL_RE).each do |email|
      flag(component, review, 'comment(email)', email) unless allowed_email?(email)
    end
  end

  def allowed_email?(value)
    value.scan(EMAIL_RE).all? do |email|
      domain = email.split('@').last&.downcase
      ALLOWED_EMAIL_DOMAINS.include?(domain)
    end
  end

  def flag(component, review, field, value)
    @pii << Finding.new(component, review['external_id'], field, value)
  end

  def load_json(file)
    return nil unless File.exist?(file)

    JSON.parse(File.read(file))
  rescue JSON::ParserError => e
    warn "  ! Failed to parse #{file}: #{e.message}"
    nil
  end
end

# Tasks for inspecting and PII-auditing Vulcan JSON Archive backups before
# they are baked into the seed pipeline as reproducible test-bed data.
#
#   bundle exec rake "seed_backup:audit[/path/to/backup-dir]"
namespace :seed_backup do
  desc 'Inspect + PII-audit a JSON Archive backup (arg: path to backup dir)'
  task :audit, [:path] do |_t, args|
    path = args[:path] or abort 'Usage: rake "seed_backup:audit[/path/to/backup-dir]"'
    abort "Not a directory: #{path}" unless File.directory?(path)

    report = BackupAuditor.new(path).run
    report.print_summary
    exit(report.clean? ? 0 : 1)
  end
end
