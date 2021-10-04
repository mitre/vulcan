# frozen_string_literal: true

# Component are home to a collection of Rules and are managed by Users.
class Component < ApplicationRecord
  belongs_to :project, inverse_of: :components
  belongs_to :child_project, class_name: 'Project', inverse_of: :parent_components

  validates :project_id,
            uniqueness: {
              scope: :child_project_id,
              message: 'already has this component'
            },
            presence: true
  validates :child_project_id, presence: true
  validate :no_circular_dependencies, :enforce_one_level_deep, :parent_cannot_be_a_component, :child_cannot_be_a_project

  ##
  # Override `as_json` to include dependent records
  #
  def as_json(options = {})
    project_admin = ProjectMember.find_by(project_id: child_project_id)&.user
    child = child_project
    super.merge(
      {
        child_project_name: child.name,
        project_admin_name: project_admin&.name,
        project_admin_email: project_admin&.email,
        rule_count: Rule.where(project_id: child_project_id).count,
        based_on: child.based_on
      }
    )
  end

  private

  def parent_cannot_be_a_component
    return unless project.component?

    errors.add(:base, 'Parent in component relationship cannot be a component')
  end

  def child_cannot_be_a_project
    return if child_project.component?

    errors.add(:base, 'Child in component relationship cannot be a project')
  end

  ##
  # Ensure that project relationships are just one level deep
  #
  # i.e. (P1 => P2, P1 => P3) is OK
  #      (P1 => P2, P2 => P3) is NOT OK
  def enforce_one_level_deep
    # Parent project cannot have any parents
    unless project.parent_components.size.zero?
      errors.add(:base, 'Component relationship is too deep due to parent project')
    end

    # Child project cannot have any children
    return if child_project.components.size.zero?

    errors.add(:base, 'Component relationship is too deep due to child project')
  end

  ##
  # Ensure that the relationship does not create any circular dependencies between projects
  #
  # Follow the child and subseqent children and ensure that the parent is not arrived at
  def no_circular_dependencies
    # For unknown reasons, the `.any?` call in true_if_parent_reached causes the `component_projects`
    # attribute of the child_project to be cleared out when directly passing `child_project` as an argument.
    # Workaround is to do a `Project.find` to get a copy of that project
    return unless true_if_parent_reached(Project.find(child_project_id))

    errors.add(:base, 'Relationship would create a circular dependency among components')
  end

  ##
  # Recursive helper function for no_circular_dependencies
  #
  # This is currently expensive for DB queries if relevant relationships are not pre-loaded somehow
  # - one optimization may be explicitly only selecting `id` from the projects table
  def true_if_parent_reached(n_child_project)
    return true if n_child_project.id == project_id

    n_child_project.component_projects.any? { |component_project| true_if_parent_reached(component_project) }
  end
end
