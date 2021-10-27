# frozen_string_literal: true

# Components are home to a collection of Rules.
class Component < ApplicationRecord
  include ExportConstants

  attr_accessor :skip_import_srg_rules

  amoeba do
    include_association :rules
    set released: false
    set rules_count: 0
  end

  audited except: %i[id admin_name admin_email memberships_count created_at updated_at], max_audits: 1000

  belongs_to :project, inverse_of: :components
  belongs_to :based_on,
             lambda {
               select(:srg_id, :title, :version)
             },
             class_name: :SecurityRequirementsGuide,
             foreign_key: 'security_requirements_guide_id',
             inverse_of: 'projects'
  has_many :rules, dependent: :destroy
  belongs_to :component, class_name: 'Component', inverse_of: :child_components, optional: true
  has_many :child_components, class_name: 'Component', inverse_of: :component, dependent: :destroy
  has_many :memberships, -> { includes :user }, inverse_of: :membership, as: :membership, dependent: :destroy

  accepts_nested_attributes_for :rules

  after_create :import_srg_rules

  validates_with PrefixValidator
  validates :prefix, :based_on, presence: true
  validate :associated_component_must_be_released,
           :rules_must_be_locked_to_release_component,
           :cannot_unrelease_component,
           :cannot_overlay_self

  def as_json(options = {})
    methods = (options[:methods] || []) + %i[releasable]
    super(options.merge(methods: methods)).merge(
      {
        based_on_title: based_on.title,
        based_on_version: based_on.version
      }
    )
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

  def duplicate(new_version: nil, new_prefix: nil)
    new_component = amoeba_dup
    new_component.version = new_version if new_version
    new_component.prefix = new_prefix if new_prefix
    new_component.skip_import_srg_rules = true
    new_component
  end

  # Benchmark: parsed XML (Xccdf::Benchmark.parse(xml))
  def from_mapping(benchmark)
    benchmark = Xccdf::Benchmark.parse(benchmark.xml)
    rule_models = benchmark.rule.each_with_index.map do |rule, idx|
      Rule.from_mapping(rule, id, idx + 1)
    end
    # Examine import results for failures
    success = Rule.import(rule_models, all_or_none: true, recursive: true).failed_instances.blank?
    if success
      Component.reset_counters(id, :rules_count)
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
    Rule.connection.execute("SELECT MAX(TO_NUMBER(rule_id, '999999')) FROM rules
                             WHERE component_id = #{id}")&.values&.flatten&.first&.to_i || 0
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

  def csv_export
    ::CSV.generate(headers: true) do |csv|
      csv << ExportConstants::DISA_EXPORT_HEADERS
      rules.each do |rule|
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
