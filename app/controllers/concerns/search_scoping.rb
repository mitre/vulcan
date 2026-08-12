# frozen_string_literal: true

# The component scope a user may search across: components of projects they
# belong to, components they hold a direct membership on, and released
# components (publicly available within Vulcan). Admins search everything.
#
# Deliberately narrower than User#available_projects: a discoverable project
# grants existence and request-access, not content, so its requirement
# identifiers stay out of search results for non-members.
module SearchScoping
  extend ActiveSupport::Concern

  private

  def searchable_components
    return Component.all if current_user.admin

    Component.where(project_id: current_user.projects.select(:id))
             .or(Component.where(id: current_user.components.select(:id)))
             .or(Component.where(released: true))
  end
end
