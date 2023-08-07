# frozen_string_literal: true

# Assists all the controllers in building fields for notifications
module SlackNotificationFieldsHelper
  include NotificationFieldsHelper

  def get_slack_notification_fields(object, notification_type, notification_type_prefix, *args)
    comment = *args

    case object
    when Component
      notification_fields = component_notification_fields(notification_type_prefix, object)
      fields = [
        app_notification_field,
        notification_fields[:generate_project_label],
        notification_fields[:generate_component_label],
        notification_fields[:generate_initiated_by_label]
      ]
    when Membership
      membership_types = %i[create_project_membership update_project_membership remove_project_membership]
      notification_fields = membership_notification_fields(notification_type_prefix, object)
      fields = [
        app_notification_field,
        if membership_types.include?(notification_type)
          notification_fields[:generate_project_label]
        else
          notification_fields[:generate_component_label]
        end,
        notification_fields[:generate_member_action_label],
        notification_fields[:generate_role_action_label],
        notification_fields[:generate_initiated_by_label]
      ]
    when Project
      notification_fields = project_notification_fields(notification_type_prefix, object)
      if notification_type_prefix == 'change_visibility'
        fields = [
          app_notification_field,
          notification_fields[:generate_project_label],
          notification_fields[:generate_initiated_by_label]
        ] << notification_fields[:generate_visibility_label]
      end
    when SecurityRequirementsGuide
      notification_fields = srg_notification_fields(notification_type_prefix, object)
      fields = [
        app_notification_field,
        notification_fields[:generate_srg_name_label],
        notification_fields[:generate_srg_version_label],
        notification_fields[:generate_initiated_by_label]
      ]
    when User
      notification_fields = user_notification_fields(notification_type_prefix, object)
      fields = [
        app_notification_field,
        notification_fields[:generate_admin_role_action_label],
        notification_fields[:generate_initiated_by_label]
      ]
    when Rule
      notification_fields = review_notification_fields(notification_type_prefix, object, comment)
      fields = [
        app_notification_field,
        notification_fields[:generate_project_label],
        notification_fields[:generate_component_label],
        notification_fields[:generate_control_label],
        notification_fields[:generate_initiated_by_label],
        notification_fields[:generate_comment_label]
      ]
    end
    fields.map do |field|
      label, value = field.values_at(:label, :value)
      label_content = label.respond_to?(:call) ? label.call(notification_type_prefix) : label
      value_content = value.respond_to?(:call) ? value.call(notification_type_prefix, object, current_user) : value
      { label: label_content, value: value_content }
    end
  end
end
