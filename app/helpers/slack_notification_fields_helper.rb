# frozen_string_literal: true

# Notification Fields which are specific to various controller/actions
module SlackNotificationFields
  MEMBERSHIP_NOTIFICATION_FIELDS = {
    generate_project_label: {
      label: 'Project',
      value: ->(_notif_prefix, membership, _current_user) { SNFH.generate_proj_or_comp_value(membership, Project) }
    },
    generate_component_label: {
      label: 'Component',
      value: ->(_notif_prefix, membership, _current_user) { SNFH.generate_proj_or_comp_value(membership, Component) }
    },
    generate_member_action_label: {
      label: ->(notif_prefix) { SNFH.generate_action_label(notif_prefix, 'Member') },
      value: lambda do |_notif_prefix, membership, _current_user|
        "#{User.find(membership.user_id).name} (#{User.find(membership.user_id).email})"
      end
    },
    generate_role_action_label: {
      label: ->(notif_prefix) { SNFH.generate_action_label(notif_prefix, 'Role') },
      value: ->(_notif_prefix, membership, _current_user) { membership.role.to_s }
    },
    generate_initiated_by_label: {
      label: ->(notif_prefix) { SNFH.generate_action_label(notif_prefix, 'By') },
      value: ->(_notification_type_prefix, _membership, current_user) { "#{current_user.name} (#{current_user.email})" }
    }
  }.freeze

  USER_NOTIFICATION_FIELDS = {
    generate_admin_role_action_label: {
      label: ->(notif_prefix) { SNFH.generate_action_label(notif_prefix, 'User') },
      value: ->(_notif_prefix, user, _current_user) { "#{user.name} (#{user.email})" }
    },
    generate_initiated_by_label: {
      label: ->(notif_prefix) { SNFH.generate_action_label(notif_prefix, 'By') },
      value: ->(_notification_type_prefix, _user, current_user) { "#{current_user.name} (#{current_user.email})" }
    }
  }.freeze

  SRG_NOTIFICATION_FIELDS = {
    generate_srg_name_label: {
      label: 'SRG Name',
      value: ->(_notif_prefix, srg, _current_user) { srg.title.to_s }
    },
    generate_srg_version_label: {
      label: 'Version',
      value: ->(_notif_prefix, srg, _current_user) { srg.version.to_s }
    },
    generate_initiated_by_label: {
      label: ->(notification_type_prefix) { SNFH.generate_action_label(notification_type_prefix, 'By') },
      value: ->(_notif_prefix, _srg, current_user) { "#{current_user.name} (#{current_user.email})" }
    }
  }.freeze

  COMPONENT_NOTIFICATION_FIELDS = {
    generate_project_label: {
      label: 'Project',
      value: lambda do |_notif_prefix, component, _current_user|
        if Settings.app_url.present?
          "<#{Settings.app_url}/projects/#{component.project.id}|#{component.project.name}>"
        else
          component.project.name.to_s
        end
      end
    },
    generate_component_label: {
      label: ->(notif_prefix) { SNFH.generate_proj_comp_action_label(notif_prefix, 'Component') },
      value: lambda do |notif_prefix, component, _current_user|
        return component.name.to_s if notif_prefix == 'remove'

        if Settings.app_url.present?
          "<#{Settings.app_url}/components/#{component.id}|#{component.name}>"
        else
          component.name.to_s
        end
      end
    },
    generate_initiated_by_label:
    {
      label: ->(notif_prefix) { SNFH.generate_proj_comp_action_label(notif_prefix, 'By') },
      value: lambda do |_notif_prefix, _component, current_user|
        "#{current_user.name} (#{current_user.email})"
      end
    }
  }.freeze

  PROJECT_NOTIFICATION_FIELDS = {
    generate_project_label: {
      label: ->(notif_prefix) { SNFH.generate_proj_comp_action_label(notif_prefix, 'Project') },
      value: lambda do |notif_prefix, project, _current_user|
        return project.name.to_s if notif_prefix == 'remove'

        if Settings.app_url.present?
          "<#{Settings.app_url}/projects/#{project.id}|#{project.name}>"
        else
          project.name.to_s
        end
      end
    },
    generate_initiated_by_label: {
      label: ->(notif_prefix) { SNFH.generate_proj_comp_action_label(notif_prefix, 'By') },
      value: lambda do |_notif_prefix, _project, current_user|
        "#{current_user.name} (#{current_user.email})"
      end
    }
  }.freeze
end

# Assists all the controllers in building fields for notifications
module SlackNotificationFieldsHelper
  include SlackNotificationFields

  GENERAL_NOTIFICATION_FIELDS = {
    generate_app_label: {
      label: 'App',
      value: Settings.app_url.present? ? "<#{Settings.app_url}|Vulcan>" : 'Vulcan'
    }
  }.freeze

  def get_slack_notification_fields(object, notification_type, notification_type_prefix)
    case object
    when Component
      fields = [
        GENERAL_NOTIFICATION_FIELDS[:generate_app_label],
        COMPONENT_NOTIFICATION_FIELDS[:generate_project_label],
        COMPONENT_NOTIFICATION_FIELDS[:generate_component_label],
        COMPONENT_NOTIFICATION_FIELDS[:generate_initiated_by_label]
      ]
    when Membership
      membership_types = %i[create_project_membership update_project_membership remove_project_membership]
      fields = [
        GENERAL_NOTIFICATION_FIELDS[:generate_app_label],
        if membership_types.include?(notification_type)
          MEMBERSHIP_NOTIFICATION_FIELDS[:generate_project_label]
        else
          MEMBERSHIP_NOTIFICATION_FIELDS[:generate_component_label]
        end,
        MEMBERSHIP_NOTIFICATION_FIELDS[:generate_member_action_label],
        MEMBERSHIP_NOTIFICATION_FIELDS[:generate_role_action_label],
        MEMBERSHIP_NOTIFICATION_FIELDS[:generate_initiated_by_label]
      ]
    when Project
      fields = [
        GENERAL_NOTIFICATION_FIELDS[:generate_app_label],
        PROJECT_NOTIFICATION_FIELDS[:generate_project_label],
        PROJECT_NOTIFICATION_FIELDS[:generate_initiated_by_label]
      ]
    when SecurityRequirementsGuide
      fields = [
        GENERAL_NOTIFICATION_FIELDS[:generate_app_label],
        SRG_NOTIFICATION_FIELDS[:generate_srg_name_label],
        SRG_NOTIFICATION_FIELDS[:generate_srg_version_label],
        SRG_NOTIFICATION_FIELDS[:generate_initiated_by_label]
      ]
    when User
      fields = [
        GENERAL_NOTIFICATION_FIELDS[:generate_app_label],
        USER_NOTIFICATION_FIELDS[:generate_admin_role_action_label],
        USER_NOTIFICATION_FIELDS[:generate_initiated_by_label]
      ]
    end
    fields.map do |field|
      label, value = field.values_at(:label, :value)
      label_content = label.respond_to?(:call) ? label.call(notification_type_prefix) : label
      value_content = value.respond_to?(:call) ? value.call(notification_type_prefix, object, current_user) : value
      { label: label_content, value: value_content }
    end
  end

  def self.generate_action_label(notification_type_prefix, action)
    labels_hash = {
      'assign' => "Assigned #{action}",
      'create' => "Added #{action}",
      'upload' => "Uploaded #{action}",
      'update' => "Updated #{action}",
      'remove' => "Removed #{action}",
      'rename' => "Renamed #{action}"
    }
    labels_hash[notification_type_prefix]
  end

  def self.generate_proj_comp_action_label(notification_type_prefix, action)
    labels_hash = {
      'create' => "Created #{action}",
      'remove' => "Removed #{action}",
      'rename' => "Renamed #{action}"
    }
    labels_hash[notification_type_prefix]
  end

  def self.generate_proj_or_comp_value(membership, model)
    object = model.find(membership.membership_id)
    if Settings.app_url.present?
      "<#{Settings.app_url}/#{model.to_s.downcase}s/#{object.id}|#{object.name}>"
    else
      object.name.to_s
    end
  end
end

# Defining an alias for SlackNotificationFieldsHelper
SNFH = SlackNotificationFieldsHelper
