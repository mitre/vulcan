# frozen_string_literal: true

# A Member is the has_many: :through Model that stores information
# about a User's membership of a Project
class Membership < ApplicationRecord
  audited except: %i[id created_at updated_at], max_audits: 1000, associated_with: :membership

  include ProjectMemberConstants

  belongs_to :membership, polymorphic: true, counter_cache: true
  belongs_to :user

  validate :cannot_have_equal_or_lesser_component_permissions
  after_destroy -> { membership.update_admin_contact_info }
  after_save -> { membership.update_admin_contact_info }
  after_save :remove_equal_or_lesser_component_permissions, if: -> { membership_type == 'Project' }

  delegate :name, to: :user
  delegate :email, to: :user

  scope :alphabetical, -> { joins(:user).order('users.name ASC') }

  validates :role, inclusion: {
    in: PROJECT_MEMBER_ROLES,
    message: "is not an acceptable value. Acceptable values are: #{PROJECT_MEMBER_ROLES.join(', ')}"
  }

  validates :user, uniqueness: {
    scope: %i[membership_type membership_id],
    message: 'is already a member of this project.'
  }

  ##
  # Override `as_json` to include additional attributes about the associated user.
  # This is useful for the ProjectMember.vue component.
  #
  def as_json(options = {})
    super options.merge(methods: %i[name email])
  end

  private

  ##
  # When the current membership is on a project, then we
  # should be removing any component level memberships that are of
  # equal or lesser permission because they will now have no effect
  # on the user's abilites
  def remove_equal_or_lesser_component_permissions
    # Gather all user's memberships for components that are children
    # of the current project
    child_component_ids = Component.where(project_id: membership_id).pluck(:id)
    component_memberships = Membership.where(
      user_id: user_id,
      membership_type: 'Component',
      membership_id: child_component_ids
    ).to_a

    # Filter down `component_memberships` to just those that are of equal or lesser permissions
    component_memberships = component_memberships.select do |membership|
      PROJECT_MEMBER_ROLES.index(membership.role) <= PROJECT_MEMBER_ROLES.index(role)
    end

    # Delete those memberships that are of equal or lesser permissions
    component_memberships.each(&:destroy)
  end

  ##
  # When the current membership is on a component, then we
  # should be validating that th role for that membership is not
  # equal or lesser permissions than that user has on the project level.
  #
  # This is because permissions are inherited from the project, and having
  # equal or lesser permissions will have no effect.
  def cannot_have_equal_or_lesser_component_permissions
    # Break early if this is a project permission
    return if membership_type == 'Project'

    # See if the user has permissions on the project
    project_membership_role = Membership.find_by(
      user_id: user_id,
      membership_type: 'Project',
      membership_id: membership.project_id
    )&.role
    # Break early if user does not have permissions on that project
    return if project_membership_role.nil?

    # Break early if the current role is greater than the project level role
    return if PROJECT_MEMBER_ROLES.index(role) > PROJECT_MEMBER_ROLES.index(project_membership_role)

    errors.add(
      :role,
      "provides equal or lesser permissions compared to the role the user's current project level role"\
      " (#{project_membership_role}). This permission would have no effect on the user's abilities."
    )
  end
end
