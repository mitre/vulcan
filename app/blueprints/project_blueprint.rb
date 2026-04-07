# frozen_string_literal: true

# Serializes Project records with context-specific views.
class ProjectBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :description, :visibility, :memberships_count,
         :admin_name, :admin_email, :created_at, :updated_at

  view :index do
    association :memberships, blueprint: MembershipBlueprint do |project, _options|
      project.memberships
    end
  end

  view :show do
    field :details do |project, _options|
      project.details
    end

    field :histories do |project, _options|
      project.histories
    end

    field :metadata do |project, _options|
      project.project_metadata&.data
    end

    association :memberships, blueprint: MembershipBlueprint do |project, _options|
      project.memberships
    end

    association :components, blueprint: ComponentBlueprint, view: :index do |project, _options|
      project.components
    end

    association :available_components, blueprint: ComponentBlueprint, view: :index do |project, _options|
      project.available_components
    end

    association :available_members, blueprint: UserBlueprint do |project, _options|
      project.available_members
    end

    association :users, blueprint: UserBlueprint do |project, _options|
      project.users
    end

    field :access_requests do |project, _options|
      project.access_requests.eager_load(:user, :project).map do |ar|
        { id: ar.id, user: UserBlueprint.render_as_hash(ar.user), project_id: ar.project_id }
      end
    end
  end
end
