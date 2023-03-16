# frozen_string_literal: true

module GeneralNotificationFields
  GENERAL_NOTIFICATION_FIELDS = {
    generate_app_label:
    {
      label: 'App',
      value: Settings.app_url.present? ? "<#{Settings.app_url}|Vulcan>" : 'Vulcan'
    }
  }.freeze
end

module MembershipNotificationFields
  MEMBERSHIP_NOTIFICATION_FIELDS = {
    generate_project_label:
    {
      label: 'Project',
      value: lambda do |membership, _current_user|
        project = Project.find(membership.membership_id)
        if Settings.app_url.present?
          "<#{Settings.app_url}/projects/#{membership.membership_id}|#{project.name}>"
        else
          project.name
        end
      end
    },
    generate_component_label:
    {
      label: 'Component',
      value: lambda do |membership, _current_user|
        component = Component.find(membership.membership_id)
        if Settings.app_url.present?
          "<#{Settings.app_url}/components/#{membership.membership_id}|#{component.name}>"
        else
          component.name
        end
      end
    },
    generate_member_action_label:
    {
      label: lambda do |notification_type_prefix|
        labels_hash = {
          'create' => 'Added Member',
          'update' => 'Updated Member',
          'remove' => 'Removed Member'
        }
        labels_hash[notification_type_prefix]
      end,
      value: lambda do |membership, _current_user|
        "#{User.find(membership.user_id).name} (#{User.find(membership.user_id).email})"
      end
    },
    generate_role_action_label:
    {
      label: lambda do |notification_type_prefix|
        labels_hash = {
          'create' => 'Added Role',
          'update' => 'Updated Role',
          'remove' => 'Removed Role'
        }
        labels_hash[notification_type_prefix]
      end,
      value: ->(membership, _current_user) { membership.role.to_s }
    },
    generate_initiated_by_label:
    {
      label: lambda do |notification_type_prefix|
        labels_hash = {
          'create' => 'Added By',
          'update' => 'Updated By',
          'remove' => 'Removed By'
        }
        labels_hash[notification_type_prefix]
      end,
      value: ->(_membership, current_user) { "#{current_user.name} (#{current_user.email})" }
    }
  }.freeze
end

module UserNotificationFields
  USER_NOTIFICATION_FIELDS = {
    generate_admin_role_action_label:
    {
      label: lambda do |notification_type_prefix|
        labels_hash = {
          'add' => 'Assigned User',
          'remove' => 'Removed User'
        }
        labels_hash[notification_type_prefix]
      end,
      value: ->(user, _current_user) { "#{user.name} (#{user.email})" }
    },
    generate_initiated_by_label:
    {
      label: lambda do |notification_type_prefix|
        labels_hash = {
          'add' => 'Assigned By',
          'remove' => 'Removed By'
        }
        labels_hash[notification_type_prefix]
      end,
      value: ->(_user, current_user) { "#{current_user.name} (#{current_user.email})" }
    }
  }.freeze
end

module ProjectNotificationFields
  PROJECT_NOTIFICATION_FIELDS = {
    generate_project_label:
    {
      label: lambda do |notification_type_prefix|
        labels_hash = {
          'create' => 'New Project',
          'remove' => 'Removed Project',
          'rename' => 'New Project'
        }
        labels_hash[notification_type_prefix]
      end,
      value: lambda do |notification_type_prefix, project, _old_project_name, _current_user|
        return project.name.to_s if notification_type_prefix == 'remove'

        if Settings.app_url.present?
          "<#{Settings.app_url}/projects/#{project.id}|#{project.name}>"
        else
          project.name.to_s
        end
      end
    },
    generate_initiated_by_label:
    {
      label: lambda do |notification_type_prefix|
        labels_hash = {
          'create' => 'Created By',
          'rename' => 'Renamed By',
          'remove' => 'Removed By'
        }
        labels_hash[notification_type_prefix]
      end,
      value: lambda do |_notification_type_prefix, _project, _old_project_name, current_user|
        "#{current_user.name} (#{current_user.email})"
      end
    },
    generate_old_project_name_label:
    {
      label: 'Old Project Name',
      value: ->(_notification_type_prefix, _project, old_project_name, _current_user) { old_project_name.to_s }
    }
  }.freeze
end

module ComponentNotificationFields
  COMPONENT_NOTIFICATION_FIELDS = {
    generate_project_label:
    {
      label: 'Project',
      value: lambda do |_notification_type_prefix, component, _current_user|
        if Settings.app_url.present?
          "<#{Settings.app_url}/projects/#{component.project.id}|#{component.project.name}>"
        else
          component.project.name.to_s
        end
      end
    },
    generate_component_label:
    {
      label: lambda do |notification_type_prefix|
        labels_hash = {
          'create' => 'New Component Name',
          'remove' => 'Deleted Component Name'
        }
        labels_hash[notification_type_prefix]
      end,
      value: lambda do |notification_type_prefix, component, _current_user|
        return component.name.to_s if notification_type_prefix == 'remove'

        if Settings.app_url.present?
          "<#{Settings.app_url}/components/#{component.id}|#{component.name}>"
        else
          component.name.to_s
        end
      end
    },
    generate_initiated_by_label:
    {
      label: lambda do |notification_type_prefix|
        labels_hash = {
          'create' => 'Created By',
          'remove' => 'Removed By'
        }
        labels_hash[notification_type_prefix]
      end,
      value: lambda do |_notification_type_prefix, _component, current_user|
        "#{current_user.name} (#{current_user.email})"
      end
    }
  }.freeze
end

module SrgNotificationFields
  SRG_NOTIFICATION_FIELDS = {
    generate_srg_name_label:
    {
      label: 'SRG Name',
      value: ->(srg, _current_user) { srg.title.to_s }
    },
    generate_srg_version_label:
    {
      label: 'Version',
      value: ->(srg, _current_user) { srg.version.to_s }
    },
    generate_initiated_by_label:
    {
      label: lambda do |notification_type_prefix|
        labels_hash = {
          'create' => 'Created By',
          'remove' => 'Removed By'
        }
        labels_hash[notification_type_prefix]
      end,
      value: ->(_srg, current_user) { "#{current_user.name} (#{current_user.email})" }
    }
  }.freeze
end

module SlackNotificationFields
  include GeneralNotificationFields
  include MembershipNotificationFields
  include UserNotificationFields
  include ProjectNotificationFields
  include ComponentNotificationFields
  include SrgNotificationFields
end
