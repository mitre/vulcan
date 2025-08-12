# frozen_string_literal: true

# Sends Email Notifications to users if Vulcan is configured to use an SMTP server
class UserMailer < ApplicationMailer
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TextHelper

  default from: Settings.smtp.settings.user_name

  def membership_action(action_type, *args)
    parse_mailer_welcome_user_args(*args)
    @subject = subject_field[action_type.to_sym]
    setting_membership_message_based_on_action_type(action_type)
    begin
      mail(
        to: @user.email,
        cc: @admins,
        subject: @subject
      )
    rescue StandardError => e
      Rails.logger.error("Error delivering welcome email to user #{@user.name}: #{e.message}")
    end
  end

  def project_access_action(action_type, *args)
    @user, @project = *args
    @subject = subject_field[action_type.to_sym]
    project_admins = get_project_or_component_admins(@project)
    setting_project_access_message_based_on_action_type(action_type)
    begin
      mail(
        to: action_type == 'reject_access' ? @user.email : project_admins,
        cc: project_admins,
        subject: @subject
      )
    rescue StandardError => e
      Rails.logger.error("Error delivering project access action email to user/admins: #{e.message}")
    end
  end

  def review_action(action_type, *args)
    parse_mailer_review_args(*args)
    @subject = subject_field[action_type.to_sym]
    @latest_review_user = find_latest_request_review(@rule, @component_id)
    setting_review_message_based_on_action_type(action_type)
    to_recipient = action_type == 'request_review' ? @component_admins : @latest_review_user&.email
    cc_recipient = action_type == 'request_review' ? @current_user.email : @component_admins
    begin
      mail(
        to: to_recipient,
        cc: cc_recipient,
        subject: @subject
      )
    rescue StandardError => e
      Rails.logger.error("Error delivering request_review by user #{@current_user.name}: #{e.message}")
    end
  end

  private

  def get_project_or_component_admins(project_or_component)
    project_or_component.admins.pluck(:email)
  end

  def parse_mailer_review_args(*args)
    @current_user, @component_id, @comment, @rule = args
    component = Component.find(@component_id)
    @stig_id = "#{component.prefix}-#{@rule.rule_id}"
    @project_id = component.project.id
    @component_admins = get_project_or_component_admins(component)
  end

  def parse_mailer_welcome_user_args(*args)
    @current_user, @membership = args
    @project_or_component = @membership.membership
    @admins = get_project_or_component_admins(@project_or_component)
    @user = @membership.user
    @role_assigned = @membership.role.to_s
  end

  def find_latest_request_review(rule, component_id)
    latest_review = Review.where(
      rule_id: Rule.find_by(rule_id: rule.rule_id.to_s, component_id: component_id).id,
      action: 'request_review'
    ).order(updated_at: :desc).first
    latest_review&.user
  end

  def subject_field
    {
      welcome_user: "Vulcan #{@project_or_component.class} Access - #{@project_or_component&.name}",
      update_membership: "Vulcan #{@project_or_component.class} Membership Role Update -
                        #{@project_or_component&.name}",
      remove_membership: "Vulcan #{@project_or_component.class} Membership Cancellation -
                        #{@project_or_component&.name}",
      request_review: "Review Requested - #{@stig_id}",
      approve: "Review Approved - #{@stig_id}",
      revoke_review_request: "Review Revoked - #{@stig_id}",
      request_changes: "Requesting Changes on the Review - #{@stig_id}",
      reject_access: "Vulcan Project Access Denied - #{@project&.name}",
      request_access: "Vulcan Project Access Request - #{@project&.name}"
    }
  end

  def setting_project_access_message_based_on_action_type(action_type)
    greeting, action_message = case action_type
                               when 'reject_access'
                                 [
                                   "Hi #{@user.name},",
                                   "Your request to access project <span class='text-blue'>" \
                                   "#{@project.name}</span> was denied.\n" \
                                   'If you believe this is an error, please contact one of the ' \
                                   "project's admins cc'd on this email."
                                 ]
                               when 'request_access'
                                 pending_request_link = link_to("project's members page", project_url(@project))
                                 [
                                   'Hi Project Admins,',
                                   "#{@user.name} has requested access to <span class='text-blue'>" \
                                   "#{@project.name}</span> project.\n" \
                                   "You can go to the #{pending_request_link} to review the pending requests."
                                 ]
                               end
    @message = simple_format("#{greeting}\n\n#{action_message}")
  end

  def setting_membership_message_based_on_action_type(action_type)
    object_class = @project_or_component.class.to_s
    url = object_class == 'Project' ? project_url(@project_or_component) : component_url(@project_or_component)

    role_markup = "<span class='text-blue'>#{@role_assigned}</span>"
    project_name_link = link_to(@project_or_component.name, url)

    action_message = case action_type
                     when 'welcome_user', 'update_membership'
                       "#{if action_type == 'welcome_user'
                            'You have been  added as'
                          else
                            'Your membership has been updated to'
                          end} " \
                       "#{role_markup} on the #{@project_or_component.name} #{object_class}."
                     when 'remove_membership'
                       "Your membership role #{role_markup} has been revoked on the " \
                       "#{@project_or_component.name} #{object_class}."
                     end

    final_part = case action_type
                 when 'welcome_user', 'update_membership'
                   "You can access the #{object_class.downcase} at #{project_name_link}."
                 when 'remove_membership'
                   "You will no longer have the #{role_markup} access privilege to that #{object_class.downcase}." \
                   '<br/>If you believe this is an error, please contact one of the ' \
                   "#{object_class.downcase}'s admins cc'd to this email."
                 end

    @message = simple_format("#{action_message}\n#{final_part}")
  end

  def setting_review_message_based_on_action_type(action_type)
    url = component_url("#{@component_id}/#{@stig_id}")

    greeting, action_message = case action_type
                               when 'request_review'
                                 ['Hi Project Admins,',
                                  "#{@current_user.name} requested review on #{link_to(@stig_id, url)}."]
                               when 'revoke_review_request'
                                 ["Hi #{@latest_review_user&.name},",
                                  "You #{action_message(action_type)} #{link_to(@stig_id, url)}."]
                               when 'approve', 'request_changes'
                                 ["Hi #{@latest_review_user&.name},",
                                  "#{@current_user.name} #{action_message(action_type)} #{link_to(@stig_id, url)}."]
                               end

    comment_message = "The #{comment_type(action_type)} comments are:"
    comment_blockquote = "<blockquote>#{@comment}</blockquote>"

    @message = simple_format("#{greeting}\n\n#{action_message}\n\n#{comment_message}\n#{comment_blockquote}")
  end

  def action_message(action_type)
    lookup = {
      approve: 'reviewed and approved the requirement',
      revoke_review_request: 'revoked your request for review on',
      request_changes: 'requested some changes on'
    }
    lookup[action_type.to_sym]
  end

  def comment_type(action_type)
    case action_type
    when 'approve'
      'approved'
    when 'revoke_review_request'
      'revoked'
    when 'request_changes'
      'requested change'
    else
      'review'
    end
  end
end
