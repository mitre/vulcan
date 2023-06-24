# frozen_string_literal: true

# Notification Fields which are specific to various controller/actions
# rubocop:disable Metrics/ModuleLength
module NotificationFieldsHelper
  include Rails.application.routes.url_helpers

  def app_notification_field
    {
      label: 'App',
      value: "<#{root_url}|Vulcan>"
    }
  end

  def project_notification_fields(notif_prefix, project)
    {
      generate_project_label: {
        label: generate_proj_comp_action_label(notif_prefix, 'Project'),
        value: notif_prefix == 'remove' ? project.name : generate_proj_or_comp_value(project, Project)
      },
      generate_initiated_by_label: {
        label: generate_proj_comp_action_label(notif_prefix, 'By'),
        value: "#{current_user.name} (#{current_user.email})"
      }
    }.freeze
  end

  def component_notification_fields(notif_prefix, component)
    {
      generate_project_label: {
        label: 'Project',
        value: generate_proj_or_comp_value(component, Project)
      },
      generate_component_label: {
        label: generate_proj_comp_action_label(notif_prefix, 'Component'),
        value: notif_prefix == 'remove' ? component.name : generate_proj_or_comp_value(component, Component)
      },
      generate_initiated_by_label:
      {
        label: generate_proj_comp_action_label(notif_prefix, 'By'),
        value: "#{current_user.name} (#{current_user.email})"
      }
    }.freeze
  end

  def membership_notification_fields(notif_prefix, membership)
    {
      generate_project_label: {
        label: 'Project',
        value: notif_prefix == 'remove' ? membership.membership.name : generate_proj_or_comp_value(membership, Project)
      },
      generate_component_label: {
        label: 'Component',
        value: if notif_prefix == 'remove'
                 membership.membership.name
               else
                 generate_proj_or_comp_value(membership,
                                             Component)
               end
      },
      generate_member_action_label: {
        label: generate_action_label(notif_prefix, 'Member'),
        value: "#{membership.user.name} (#{membership.user.email})"
      },
      generate_role_action_label: {
        label: generate_action_label(notif_prefix, 'Role'),
        value: membership.role.to_s
      },
      generate_initiated_by_label: {
        label: generate_action_label(notif_prefix, 'By'),
        value: "#{current_user.name} (#{current_user.email})"
      }
    }.freeze
  end

  def srg_notification_fields(notification_type_prefix, srg)
    {
      generate_srg_name_label: {
        label: 'SRG Name',
        value: srg.title.to_s
      },
      generate_srg_version_label: {
        label: 'Version',
        value: srg.version.to_s
      },
      generate_initiated_by_label: {
        label: generate_action_label(notification_type_prefix, 'By'),
        value: "#{current_user.name} (#{current_user.email})"
      }
    }.freeze
  end

  def user_notification_fields(notif_prefix, user)
    {
      generate_admin_role_action_label: {
        label: generate_action_label(notif_prefix, 'User'),
        value: "#{user.name} (#{user.email})"
      },
      generate_initiated_by_label: {
        label: generate_action_label(notif_prefix, 'By'),
        value: "#{current_user.name} (#{current_user.email})"
      }
    }.freeze
  end

  def review_notification_fields(notif_prefix, object, comment)
    {
      generate_project_label: {
        label: 'Project',
        value: generate_proj_or_comp_value(object, Project)
      },
      generate_component_label: {
        label: 'Component',
        value: generate_proj_or_comp_value(object, Component)
      },
      generate_control_label: {
        label: 'Control',
        value: generate_proj_or_comp_value(object, Rule)
      },
      generate_comment_label: {
        label: 'Comment',
        value: comment
      },
      generate_initiated_by_label: {
        label: generate_action_label(notif_prefix, 'By'),
        value: "#{current_user.name} (#{current_user.email})"
      }
    }.freeze
  end

  private

  def generate_action_label(notification_type_prefix, action)
    labels_hash = {
      'assign' => "Assigned #{action}",
      'create' => "Added #{action}",
      'upload' => "Uploaded #{action}",
      'update' => "Updated #{action}",
      'remove' => "Removed #{action}",
      'rename' => "Renamed #{action}",
      'approve' => "Approved #{action}",
      'revoke' => "Revoked #{action}",
      'request_changes' => "Requested #{action}",
      'request_review' => "Requested #{action}"
    }
    labels_hash[notification_type_prefix]
  end

  def generate_proj_or_comp_value(object, model)
    proj_or_comp = object if object.is_a?(Project) && model == Project
    proj_or_comp = object if object.is_a?(Component) && model == Component
    proj_or_comp = object.project if object.is_a?(Component) && model == Project
    proj_or_comp = object.membership if object.is_a?(Membership)
    proj_or_comp = object.component if object.is_a?(Rule) && [Component, Rule].include?(model)
    proj_or_comp = object.component.project if object.is_a?(Rule) && model == Project
    url = model == Project ? project_url(proj_or_comp) : component_url(proj_or_comp)
    if model == Rule
      stig_id = "#{proj_or_comp.prefix}-#{object.rule_id}"
      url = "#{url}/#{stig_id}"
      return "<#{url}/#{stig_id}|#{stig_id}>"
    end
    "<#{url}|#{proj_or_comp.name}>"
  end

  def generate_proj_comp_action_label(notification_type_prefix, action)
    labels_hash = {
      'create' => "Created #{action}",
      'remove' => "Removed #{action}",
      'rename' => "Renamed #{action}"
    }
    labels_hash[notification_type_prefix]
  end
end
# rubocop:enable Metrics/ModuleLength
