# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module SeedHelpers # rubocop:disable Style/Documentation
  DEMO_PASSWORD = ENV.fetch('VULCAN_SEED_ADMIN_PASSWORD', '12qwaszx!@QWASZX')
  DEMO_EMAILS = %w[admin@example.com viewer@example.com author@example.com reviewer@example.com].freeze

  # rubocop:disable Rails/Output
  def self.seed_xccdf(filepath)
    xml = File.read(filepath)
    parsed = Xccdf::Benchmark.parse(xml)
    title = parsed.try(:title)&.first&.downcase || ''

    is_srg = title.include?('requirements guide') || filepath.to_s.include?('/srgs/')
    is_stig = title.include?('implementation guide') || title.include?('stig') || filepath.to_s.include?('/stigs/')

    if is_srg
      record = SecurityRequirementsGuide.from_mapping(parsed)
      existing = SecurityRequirementsGuide.find_by(srg_id: record.srg_id)
      if existing
        puts "  Already exists: #{existing.name} (SecurityRequirementsGuide)"
        return existing
      end
      record.xml = xml
    elsif is_stig
      record = Stig.from_mapping(parsed)
      existing = Stig.find_by(stig_id: record.stig_id)
      if existing
        puts "  Already exists: #{existing.name} (Stig)"
        return existing
      end
      record.xml = Nokogiri::XML(xml)
    else
      puts "  Skipping #{File.basename(filepath)} (unrecognized benchmark type)"
      return nil
    end

    record.save!
    puts "  Loaded #{record.name} (#{record.class.name})"
    record
  end
  # rubocop:enable Rails/Output

  def self.seed_component(**opts)
    project  = opts.fetch(:project)
    name     = opts.fetch(:name)
    title    = opts.fetch(:title)
    prefix   = opts.fetch(:prefix)
    based_on = opts.fetch(:based_on)
    version  = opts.fetch(:version, 1)
    release  = opts.fetch(:release, 1)

    raise ArgumentError, "seed_component: based_on (SRG) is nil for '#{name}'" unless based_on

    c = Component.find_or_initialize_by(project: project, name: name, version: version, release: release)
    c.title = title
    c.prefix = prefix
    c.based_on = based_on
    extra_keys = opts.keys - %i[project name title prefix based_on version release]
    extra_keys.each { |k| c.send(:"#{k}=", opts[k]) }
    c.save!
    c
  end

  def self.find_or_seed_review(rule:, user:, section:, comment:, **extra)
    existing = Review.find_by(action: 'comment', comment: comment)
    return existing if existing

    Review.create!(
      user: user, rule: rule, action: 'comment',
      section: section, comment: comment, **extra
    )
  end

  def self.find_or_seed_reply(parent:, user:, comment:)
    existing = Review.find_by(responding_to_review_id: parent.id, comment: comment)
    return existing if existing

    Review.create!(
      user: user, rule: parent.rule, action: 'comment',
      section: parent.section, comment: comment,
      responding_to_review_id: parent.id
    )
  end

  def self.seed_triage(review, user:, status:)
    return if review.triage_status == status

    attrs = { triage_status: status, triage_set_by_id: user.id, triage_set_at: Time.current }
    if Review::TERMINAL_AUTO_ADJUDICATE_STATUSES.include?(status)
      attrs[:adjudicated_at] = Time.current
      attrs[:adjudicated_by_id] = status == 'withdrawn' ? review.user_id : user.id
    end
    review.update!(attrs)
  end

  def self.status_report
    {
      users: User.count,
      projects: Project.count,
      srgs: SecurityRequirementsGuide.count,
      stigs: Stig.count,
      components: Component.count,
      rules: BaseRule.where(type: 'Rule').count,
      memberships: Membership.count,
      comments: Review.where(action: 'comment', responding_to_review_id: nil).count,
      replies: Review.where(action: 'comment').where.not(responding_to_review_id: nil).count
    }
  end

  def self.verify!
    errors = []
    errors << 'No admin user' unless User.exists?(admin: true)
    errors << "No projects (expected >= 4, got #{Project.count})" unless Project.count >= 4
    errors << "No SRGs (expected >= 1, got #{SecurityRequirementsGuide.count})" unless SecurityRequirementsGuide.count >= 1
    errors << "No components (expected >= 4, got #{Component.count})" unless Component.count >= 4

    expected_roles = %w[viewer author reviewer admin]
    demo_projects = Project.where(name: ['Photon 3', 'Photon 4', 'vSphere 7.0', 'Container Platform'])
    demo_projects.find_each do |p|
      roles = p.memberships.pluck(:role).uniq
      expected_roles.each do |role|
        errors << "Project '#{p.name}' missing #{role} membership" unless roles.include?(role)
      end
    end

    top_level = Review.where(action: 'comment', responding_to_review_id: nil).count
    errors << "Too few top-level comments (expected >= 18, got #{top_level})" unless top_level >= 18

    statuses = Review.where(action: 'comment').distinct.pluck(:triage_status).compact
    %w[pending concur non_concur informational withdrawn].each do |s|
      errors << "Missing triage status '#{s}' in seed data" unless statuses.include?(s)
    end

    errors
  end
end
# rubocop:enable Metrics/ModuleLength
