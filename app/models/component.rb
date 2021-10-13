# frozen_string_literal: true

# Components are home to a collection of Rules.
class Component < ApplicationRecord
  attr_accessor :skip_import_srg_rules

  amoeba do
    include_association :rules
  end

  audited except: %i[id memberships_count created_at updated_at], max_audits: 1000

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
    component_admin = admin
    super(options.merge(methods: methods)).merge(
      {
        based_on_title: based_on.title,
        based_on_version: based_on.version,
        rule_count: rules.size,
        admin_name: component_admin&.name,
        admin_email: component_admin&.email
      }
    )
  end

  ##
  # Get a user that has admin permission on the component
  #
  # Priority:
  # - admin on the component itself
  # - admin on the owning project
  # - `nil`
  def admin
    admin_memberships = Membership.where(
      membership_type: 'Component',
      membership_id: id,
      role: 'admin'
    ).or(
      Membership.where(
        membership_type: 'Project',
        membership_id: project_id,
        role: 'admin'
      )
    ).includes(:user)
    admin_component_membership = admin_memberships.select { |member| member.membership_type == 'Component' }
    admin_project_membership = admin_memberships.select { |member| member.membership_type == 'Project' }

    admin_component_membership&.first&.user || admin_project_membership&.first&.user || nil
  end

  def releasable
    # If already released, then it cannot be released again
    return false if released_was

    # If all rules are locked, then component may be released
    rules.where(locked: false).size.zero?
  end

  def duplicate(new_version: nil)
    new_component = amoeba_dup
    new_component.version = new_version if new_version
    new_component.released = false
    new_component.skip_import_srg_rules = true
    new_component
  end

  # Benchmark: parsed XML (Xccdf::Benchmark.parse(xml))
  def from_mapping(benchmark)
    # Break early if the `skip_import_srg_rules` has been set to a true value
    return true if skip_import_srg_rules

    benchmark = Xccdf::Benchmark.parse(benchmark.xml)
    rule_models = benchmark.rule.map do |rule|
      Rule.from_mapping(rule, id)
    end
    # Examine import results for failures
    success = Rule.import(rule_models, all_or_none: true, recursive: true).failed_instances.blank?
    reload if success
    errors.add(:base, 'Some rules failed to import successfully for the component.') unless success
    success
  rescue StandardError => e
    message = e.message[0, 50]
    message += '...' if e.message.size >= 50
    errors.add(:base, "Encountered and error when importing rules from the SRG: #{message}")
    false
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

  private

  def import_srg_rules
    # We assume that we will automatically add the SRG rules within the transaction of the inital creation
    # if the `component_id` is `nil` and if `security_requirements_guide_id` if present
    return unless component_id.nil? && security_requirements_guide_id.present?

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
    return unless released

    # If rule is releasable, then this validation passes
    return if releasable

    errors.add(:base, 'Cannot release a component that contains rules that are not yet locked')
  end
end
