# frozen_string_literal: true

# Components are home to a collection of Rules.
class Component < ApplicationRecord
  include RuleConstants
  include ImportConstants
  include ExportConstants
  include ActionView::Helpers::TextHelper

  attr_accessor :skip_import_srg_rules

  amoeba do
    include_association :component_metadata
    include_association :rules
    include_association :additional_questions
    set released: false
    set rules_count: 0

    customize(lambda { |original_component, new_component|
      # There is unfortunately no way to do this at a lower level since the new component isn't
      # accessible until amoeba is processing at this level
      new_component.additional_questions.each do |question|
        question.additional_answers.each do |answer|
          answer.rule = new_component.rules.find { |r| r.rule_id == answer.rule.rule_id }
        end
      end

      # Cloning the habtm relationship just doesn't work here since it tries to create a new rule
      # and doesn't intelligently link to the existing rule. This code loops over every rules satisfies
      # and uses the "rule_id" to recreate the same linking relationships that existed on the original_component.
      original_component.rules.each do |orig_rule|
        orig_rule.satisfies.each do |orig_satisfies|
          # By waiting until the loop to find the new rule it helps eliminte unnecessary finds.
          new_rule = new_component.rules.find { |r| r.rule_id == orig_rule.rule_id }
          new_rule_satisfies = new_component.rules.find { |r| r.rule_id == orig_satisfies.rule_id }
          new_rule.satisfies << new_rule_satisfies
        end
      end
    })
  end

  audited except: %i[id admin_name admin_email rules_count memberships_count created_at updated_at], max_audits: 1000
  has_associated_audits

  belongs_to :project, inverse_of: :components
  belongs_to :based_on,
             lambda {
               select(:srg_id, :title, :version)
             },
             class_name: :SecurityRequirementsGuide,
             foreign_key: 'security_requirements_guide_id',
             inverse_of: 'components'
  has_many :rules, dependent: :destroy
  belongs_to :component, class_name: 'Component', inverse_of: :child_components, optional: true
  has_many :child_components, class_name: 'Component', inverse_of: :component, dependent: :destroy
  has_many :memberships, -> { includes :user }, inverse_of: :membership, as: :membership, dependent: :destroy
  has_one :component_metadata, dependent: :destroy

  has_many :additional_questions, dependent: :destroy

  accepts_nested_attributes_for :rules, :component_metadata, :additional_questions, allow_destroy: true

  after_create :import_srg_rules

  validates_with PrefixValidator

  validates :prefix, presence: true
  validate :associated_component_must_be_released,
           :rules_must_be_locked_to_release_component,
           :cannot_unrelease_component,
           :cannot_overlay_self

  def as_json(options = {})
    methods = (options[:methods] || []) + %i[releasable additional_questions]
    super(options.merge(methods: methods)).merge(
      {
        based_on_title: based_on.title,
        based_on_version: based_on.version
      }
    )
  end

  # Fill out component based on spreadsheet
  def from_spreadsheet(spreadsheet)
    self.skip_import_srg_rules = true
    # Parse the spreadsheet and extract data from the first sheet. Include headers so data is of the form
    # {VulDiscussion: 'Value', SRG ID: 'Value', etc...}
    parsed = Roo::Spreadsheet.open(spreadsheet).sheet(0).parse(headers: true).drop(1)
    file_headers = parsed.first.keys
    # Since the component isn't saved yet, calling `based_on` here returns the wrong information
    srg_rules = SecurityRequirementsGuide.find(security_requirements_guide_id).srg_rules

    missing_headers = REQUIRED_MAPPING_CONSTANTS.values - file_headers
    unless missing_headers.empty?
      errors.add(:base, "The following required headers were missing #{missing_headers.join(', ')}")
      return
    end

    spreadsheet_srg_ids = parsed.map { |row| row[IMPORT_MAPPING[:srg_id]] }
    database_srg_ids = srg_rules.map(&:version)

    missing_from_srg = spreadsheet_srg_ids - database_srg_ids
    unless missing_from_srg.empty?
      errors.add(:base, 'The following required SRG IDs were missing from the selected SRG '\
                        "#{truncate(missing_from_srg.join(', '), length: 300)}. "\
                        'Please remove these rows or select a different SRG and try again.')
      return
    end

    missing_from_spreadsheet = database_srg_ids - spreadsheet_srg_ids

    # Missing rows from the spreadsheet should still be present in the database
    missing_from_spreadsheet.each do |missing|
      row = file_headers.index_with { |_key| '' }
      row[IMPORT_MAPPING[:srg_id]] = missing
      parsed << row
    end

    # Calculate the prefix (which will need to be removed from each row)
    possible_prefixes = parsed.collect { |row| row[IMPORT_MAPPING[:stig_id]] }.compact_blank
    if possible_prefixes.empty?
      errors.add(:base, 'No STIG prefixes were detected in the file. Please set any STIGID '\
                        'in the file and try again.')
      return
    else
      self.prefix = possible_prefixes.first[0, 7]
    end

    self.rules = parsed.map do |row|
      srg_rule = srg_rules.find { |rule| rule.version == row[IMPORT_MAPPING[:srg_id]] }
      # Clone existing SRGRule. This is setup in srg_rule.rb to automatically create a Rule from the result of a dup.
      r = srg_rule.amoeba_dup

      # Remove the prefix and remove any non-digits
      r.rule_id = row[IMPORT_MAPPING[:stig_id]]&.sub(prefix, '')&.delete('^0-9')
      r.title = row[IMPORT_MAPPING[:title]]
      r.fixtext = row[IMPORT_MAPPING[:fixtext]]
      r.artifact_description = row[IMPORT_MAPPING[:artifact_description]]
      r.status_justification = row[IMPORT_MAPPING[:status_justification]]
      r.vendor_comments = row[IMPORT_MAPPING[:vendor_comments]]
      # Get status with the case ignored. If none is found then fall back to the default status
      status_index = STATUSES.find_index { |item| item.casecmp(row[IMPORT_MAPPING[:status]])&.zero? }
      r.status = status_index ? STATUSES[status_index] : STATUSES[0]
      # Severities are provided in the spreadsheet in the form CAT I II or III, however they are
      # stored in vulcan in 'low', 'medium', 'high'. If the spreadsheet value cannot be mapped then
      # fall back to the default from the SRG. Since this is a clone of an SRGRule, by not setting
      # anything the value from the SRGRule will be propagated to this rule.
      severity = SEVERITIES_MAP.invert[row[IMPORT_MAPPING[:rule_severity]]&.upcase]
      r.rule_severity = severity if severity
      r.srg_rule_id = srg_rule.id

      disa_rule_description = r.disa_rule_descriptions.first
      disa_rule_description.vuln_discussion = row[IMPORT_MAPPING[:vuln_discussion]]
      disa_rule_description.mitigations = row[IMPORT_MAPPING[:mitigation]]

      check = r.checks.first
      check.content = row[IMPORT_MAPPING[:check_content]]

      r
    end
  end

  # Helper method to extract data from Component Metadata
  def metadata
    component_metadata&.data
  end

  ##
  # Helper to get the memberships associated with the parent project
  #
  # Excludes users that already have permissions on the component
  # because we can assume that those component permissions are greater
  # than those on the project for that user.
  def inherited_memberships
    project.memberships.where.not(user_id: memberships.pluck(:user_id))
  end

  def update_admin_contact_info
    admin_members = admins
    admin_component_membership = admin_members.select { |member| member.membership_type == 'Component' }
    admin_project_membership = admin_members.select { |member| member.membership_type == 'Project' }

    if admin_component_membership.present?
      self.admin_name = admin_component_membership.first.name
      self.admin_email = admin_component_membership.first.email
    elsif admin_project_membership.present?
      self.admin_name = admin_project_membership.first.name
      self.admin_email = admin_project_membership.first.email
    else
      self.admin_name = nil
      self.admin_email = nil
    end
    save if admin_name_changed? || admin_email_changed?
  end

  ##
  # Get information for users that have admin permission on the component
  #
  # Priority:
  # - admin on the component itself
  # - admin on the owning project
  # - `nil`
  def admins
    Membership.where(
      membership_type: 'Component',
      membership_id: id,
      role: 'admin'
    ).or(
      Membership.where(
        membership_type: 'Project',
        membership_id: project_id,
        role: 'admin'
      )
    ).eager_load(:user).select(:user_id, :name, :email, :membership_type)
  end

  def releasable
    # If already released, then it cannot be released again
    return false if released_was

    # If all rules are locked, then component may be released
    rules.where(locked: false).size.zero?
  end

  def duplicate(new_name: nil, new_prefix: nil, new_version: nil, new_release: nil,
                new_title: nil, new_description: nil, new_project_id: nil, new_srg_id: nil)
    new_component = amoeba_dup
    new_component.name = new_name if new_name
    new_component.prefix = new_prefix if new_prefix
    new_component.version = new_version if new_version
    new_component.release = new_release if new_release
    new_component.title = new_title if new_title
    new_component.description = new_description if new_description
    new_component.project_id = new_project_id if new_project_id
    new_component.skip_import_srg_rules = true
    return new_component unless new_srg_id

    new_srg = SecurityRequirementsGuide.find_by(id: new_srg_id)
    return new_component if new_srg.nil? || (new_srg.srg_id == based_on.srg_id && new_srg.version == based_on.version)

    new_rules = new_srg.srg_rules.index_by(&:version)
    # update rules that haven't been configured
    new_component.rules.where.not(status: 'Applicable - Configurable').find_each do |old_rule|
      new_rule = new_rules[old_rule[:version]]
      # delete rules that are no longer present
      old_rule.destroy! && next if new_rule.blank?

      fields = %i[rule_severity rule_weight title ident ident_system fixtext fixtext_fixref fix_id]
      fields.each { |field| old_rule[field] = new_rule[field] }
      old_rule.disa_rule_descriptions = new_rule.disa_rule_description.dup
      old_rule.rule_descriptions = new_rule.rule_descriptions.dup
      old_rule.checks = new_rule.checks.dup
      old_rule.srg_rule = new_rule
    end

    # import any new rules
    new_rule_versions = (new_rules.keys - new_component.rules.pluck(:version))
    raise ActiveRecord::RecordInvalid, self unless from_mapping(new_srg, new_rule_versions, new_component.rules.size)

    new_component
  end

  def duplicate_reviews_and_history(component_id)
    return unless component_id

    Component.find(component_id).rules.each do |orig_rule|
      new_rule = rules.find { |r| r.rule_id == orig_rule.rule_id }
      next if new_rule.nil?

      ActiveRecord::Base.connection.execute(
        Arel.sql("UPDATE base_rules SET created_at = '#{orig_rule.created_at}', updated_at = '#{orig_rule.updated_at}'
                  WHERE id = #{new_rule.id}")
      )

      ActiveRecord::Base.connection.execute(
        Arel.sql("DELETE FROM audits WHERE auditable_type = 'BaseRule' AND auditable_id = #{new_rule.id}")
      )

      ActiveRecord::Base.connection.execute(
        Arel.sql("INSERT INTO audits (auditable_id, auditable_type, associated_id, associated_type, user_id, user_type,
                                      username, action, audited_changes, version, comment, remote_address, request_uuid,
                                      created_at, audited_user_id, audited_username)
                  SELECT #{new_rule.id}, auditable_type, associated_id, associated_type, user_id, user_type, username,
                         action, audited_changes, version, comment, remote_address, request_uuid, created_at,
                         audited_user_id, audited_username
                  FROM audits WHERE auditable_type = 'BaseRule' AND auditable_id = #{orig_rule.id}")
      )

      ActiveRecord::Base.connection.execute(
        Arel.sql("INSERT INTO reviews (user_id, rule_id, action, comment, created_at, updated_at)
                  SELECT user_id, #{new_rule.id}, action, comment, created_at, updated_at
                  FROM reviews WHERE rule_id = #{orig_rule.id}")
      )
    end
  end

  def create_rule_satisfactions
    rules.where('vendor_comments LIKE ?', '%Satisfied By: %').find_each do |rule|
      vc = rule.vendor_comments.split
      sb = vc[vc.index('By:') + 1]
      next if sb.nil?

      sb_rule_id = sb.delete('.').split('-').last
      sb_rule = rules.find_by(rule_id: sb_rule_id)
      next if sb_rule.nil?

      rule.satisfied_by << sb_rule
    end
  end

  def overlay(project_id)
    new_component = amoeba_dup
    new_component.project_id = project_id
    new_component.component_id = id
    new_component
  end

  # Benchmark: parsed XML (Xccdf::Benchmark.parse(xml))
  def from_mapping(srg, new_rule_versions = nil, starting_idx = 0)
    benchmark = srg.parsed_benchmark

    filtered_srg_rules = new_rule_versions.present? ? srg.srg_rules.where(version: new_rule_versions) : srg.srg_rules
    srg_rules = filtered_srg_rules.pluck(:rule_id, :id).to_h
    srg_rule_versions = filtered_srg_rules.pluck(:rule_id, :version).to_h

    filtered_benchmark_rules = if new_rule_versions.present?
                                 benchmark.rule.filter { |r| new_rule_versions.include?(r.version.first.version) }
                               else
                                 benchmark.rule
                               end
    rule_models = filtered_benchmark_rules.sort_by { |r| srg_rule_versions[r.id] }.each_with_index.map do |rule, idx|
      Rule.from_mapping(rule, id, starting_idx + idx + 1, srg_rules)
    end
    # Examine import results for failures
    success = Rule.import(rule_models, all_or_none: true, recursive: true).failed_instances.blank?
    if success
      reload
    else
      errors.add(:base, 'Some rules failed to import successfully for the component.')
    end
    success
  rescue StandardError => e
    message = e.message[0, 50]
    message += '...' if e.message.size >= 50
    errors.add(:base, "Encountered an error when importing rules from the SRG: #{message}")
    false
  end

  def largest_rule_id
    # rule_id is a string, convert it to a number and then extract the current highest number.
    if id.nil?
      rules.collect { |rule| rule.rule_id.to_i }.max
    else
      Rule.connection.execute("SELECT MAX(TO_NUMBER(rule_id, '999999')) FROM base_rules
                              WHERE component_id = #{id}")&.values&.flatten&.first&.to_i || 0
    end
  end

  def prefix=(val)
    self[:prefix] = val&.upcase
  end

  ##
  # Available members for a component are:
  # - not an admin on the project (due to equal or lesser permissions constraint)
  # - not already memebers of the component
  def available_members
    exclude_user_ids = Membership.where(
      membership_type: 'Project',
      membership_id: project_id,
      role: 'admin'
    ).or(
      Membership.where(
        membership_type: 'Component',
        membership_id: id
      )
    ).pluck(:user_id)
    User.where.not(id: exclude_user_ids).select(:id, :name, :email)
  end

  def reviews
    rule_ids = rules.to_h { |r| [r.id, r.displayed_name] }
    Review.where(rule: rules).order(created_at: :desc).limit(20).as_json.map do |review|
      review['displayed_rule_name'] = rule_ids[review['rule_id'].to_i]
      review
    end
  end

  def csv_export
    ::CSV.generate(headers: true) do |csv|
      csv << ExportConstants::DISA_EXPORT_HEADERS
      rules.eager_load(:reviews, :disa_rule_descriptions, :rule_descriptions, :checks, :additional_answers, :satisfies,
                       :satisfied_by, srg_rule: %i[disa_rule_descriptions rule_descriptions checks])
           .order(:version, :rule_id).each do |rule|
        csv << rule.csv_attributes
      end
    end
  end

  private

  def import_srg_rules
    # We assume that we will automatically add the SRG rules within the transaction of the inital creation
    # if the `component_id` is `nil` and if `security_requirements_guide_id` if present
    return unless component_id.nil? && security_requirements_guide_id.present?

    # Break early if the `skip_import_srg_rules` has been set to a true value
    return if skip_import_srg_rules

    # Break early if all rules imported without any issues
    return if from_mapping(SecurityRequirementsGuide.find(security_requirements_guide_id))

    raise ActiveRecord::RecordInvalid, self
  end

  def cannot_overlay_self
    # Break early if the component is not an overlay or if `id != component_id`
    return if component_id.nil? || id != component_id

    errors.add(:component_id, 'cannot overlay itself')
  end

  def cannot_unrelease_component
    # Error if component was released and has been changed to released = false
    return unless released_was && !released

    errors.add(:base, 'Cannot unrelease a released component')
  end

  def associated_component_must_be_released
    # If this isn't an imported component, then skip this vaildation
    return if component_id.nil? || component.released

    errors.add(:base, 'Cannot overlay a component that has not been released')
  end

  # All rules associated with the component should be in a locked state in order
  # for the component to be released.
  def rules_must_be_locked_to_release_component
    # If rule is not released, then skip this validation
    return if !released || (released && released_was == true)

    # If rule is releasable, then this validation passes
    return if releasable

    errors.add(:base, 'Cannot release a component that contains rules that are not yet locked')
  end
end
