# frozen_string_literal: true

# Sends Email Notifications to users if Vulcan is configured to use an SMTP server
class UserMailer < ApplicationMailer
  def welcome_member(*args)
    parse_mailer_welcome_user_args(*args)
    subject = if @project_or_component.is_a?(Project)
                "Vulcan Project Access - #{@project_or_component.name}"
              else
                "Vulcan Component Access - #{@project_or_component.name}"
              end
    begin
      mail(
        to: @user.email,
        cc: @admins,
        subject: subject,
        from: Settings.smtp.settings.user_name
      )
    rescue StandardError => e
      Rails.logger.error("Error delivering welcome email to user #{@user.name}: #{e.message}")
    end
  end

  def request_review(*args)
    parse_mailer_review_args(*args)
    begin
      mail(
        to: @component_admins,
        cc: @current_user.email,
        subject: "Review Requested - #{@stig_id}",
        from: Settings.smtp.settings.user_name
      )
    rescue StandardError => e
      Rails.logger.error("Error delivering request_review by user #{@current_user.name}: #{e.message}")
    end
  end

  def approve_review(*args)
    parse_mailer_review_args(*args)
    @latest_review_user = find_latest_request_review(@rule, @component_id)
    begin
      mail(
        to: @latest_review_user.email,
        cc: @component_admins,
        subject: "Review Approved - #{@stig_id}",
        from: Settings.smtp.settings.user_name
      )
    rescue StandardError => e
      Rails.logger.error("Error delivering approve_review by user #{@current_user.name}: #{e.message}")
    end
  end

  def revoke_review(*args)
    parse_mailer_review_args(*args)
    @latest_review_user = find_latest_request_review(@rule, @component_id)
    begin
      mail(
        to: @latest_review_user.email,
        cc: @component_admins,
        subject: "Review Revoked - #{@stig_id}",
        from: Settings.smtp.settings.user_name
      )
    rescue StandardError => e
      Rails.logger.error("Error delivering revoke_review_request by user #{@current_user.name}: #{e.message}")
    end
  end

  def request_review_changes(*args)
    parse_mailer_review_args(*args)
    @latest_review_user = find_latest_request_review(@rule, @component_id)
    begin
      mail(
        to: @latest_review_user.email,
        cc: @component_admins,
        subject: "Requesting Changes on the Review - #{@stig_id}",
        from: Settings.smtp.settings.user_name
      )
    rescue StandardError => e
      Rails.logger.error("Error delivering request_review_changes by user #{@current_user.name}: #{e.message}")
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
    latest_review.user
  end
end
