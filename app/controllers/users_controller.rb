# frozen_string_literal: true

##
# Controller for application users.
#
class UsersController < ApplicationController
  USER_JSON_FIELDS = %i[id name email provider admin failed_attempts locked_at].freeze

  before_action :authorize_admin
  before_action :set_user, only: %i[update destroy send_password_reset generate_reset_link set_password lock unlock]

  def index
    @users = User.alphabetical.select(:id, :name, :email, :provider, :admin, :last_sign_in_at,
                                      :failed_attempts, :locked_at)
    @histories = Audited.audit_class.includes(:auditable, :user)
                        .where(auditable_type: 'User')
                        .order(created_at: :desc)
                        .limit(200)
                        .map(&:format)
  end

  def admin_create
    user = User.new(user_create_params)
    user.skip_confirmation!

    # Use admin-provided password if given, otherwise generate one
    user.password = user.password_confirmation =
      (password_params[:password].presence || generate_compliant_password)

    if user.save
      result = { user: user.as_json(only: USER_JSON_FIELDS) }

      if password_params[:password].present?
        result[:toast] = "User #{user.email} created with the provided password."
      elsif Settings.smtp.enabled
        user.send_reset_password_instructions
        result[:toast] = "User #{user.email} created. Setup email sent."
      else
        # No SMTP + no password provided — generate a reset link for the admin to deliver
        reset_url = generate_reset_url(user)
        result[:toast] = "User #{user.email} created. Deliver the reset link to the user."
        result[:reset_url] = reset_url
      end

      render json: result
    else
      render json: {
        toast: { title: 'Could not create user.', message: user.errors.full_messages, variant: 'danger' }
      }, status: :unprocessable_content
    end
  end

  def update
    # Prevent the last admin from demoting themselves
    if @user == current_user && ActiveModel::Type::Boolean.new.cast(user_update_params[:admin]) == false && User.where(admin: true).one?
      return respond_to do |format|
        format.html do
          flash.alert = 'Cannot remove admin privileges. You are the only admin.'
          redirect_to action: 'index'
        end
        format.json do
          render json: {
            toast: { title: 'Cannot remove admin.', message: ['You are the only admin. Promote another user first.'], variant: 'danger' }
          }, status: :unprocessable_content
        end
      end
    end

    @user.skip_reconfirmation! if user_update_params[:email].present?

    if @user.update(user_update_params)
      # Only notify Slack when the admin flag actually changed. Previously this
      # fired on every update (e.g. name change, email change), spamming Slack
      # with "promoted/demoted" messages that weren't accurate.
      if @user.saved_change_to_admin?
        notification_type = @user.admin ? :assign_vulcan_admin : :remove_vulcan_admin
        send_slack_notification(notification_type, @user) if Settings.slack.enabled
      end

      respond_to do |format|
        format.html do
          flash.notice = 'Successfully updated user.'
          redirect_to action: 'index'
        end
        format.json { render json: { toast: 'Successfully updated user', user: @user.as_json(only: USER_JSON_FIELDS) } }
      end
    else
      respond_to do |format|
        format.html do
          flash.alert = "Unable to update user. #{@user.errors.full_messages}"
          redirect_to action: 'index'
        end
        format.json do
          render json: {
            toast: {
              title: 'Could not update user.',
              message: @user.errors.full_messages,
              variant: 'danger'
            }
          }, status: :unprocessable_content
        end
      end
    end
  end

  def destroy
    # Prevent deleting the last admin
    if @user.admin? && User.where(admin: true).one?
      return respond_to do |format|
        format.html do
          flash.alert = 'Cannot delete the only admin. Promote another user first.'
          redirect_to action: 'index'
        end
        format.json do
          render json: {
            toast: { title: 'Cannot delete user.', message: ['This is the only admin. Promote another user first.'], variant: 'danger' }
          }, status: :unprocessable_content
        end
      end
    end

    if @user.destroy
      respond_to do |format|
        format.html do
          flash.notice = 'Successfully removed user.'
          redirect_to action: 'index'
        end
        format.json { render json: { toast: 'Successfully removed user.' } }
      end
    else
      respond_to do |format|
        format.html do
          flash.alert = "Unable to remove user. #{@user.errors.full_messages}"
          redirect_to action: 'index'
        end
        format.json do
          render json: {
            toast: {
              title: 'Could not remove user.',
              message: @user.errors.full_messages,
              variant: 'danger'
            }
          }, status: :unprocessable_content
        end
      end
    end
  end

  # Send Devise reset email (requires SMTP)
  def send_password_reset
    unless Settings.smtp.enabled
      return render json: {
        toast: { title: 'SMTP not configured.', message: ['Email delivery is not available. Use "Generate Reset Link" instead.'], variant: 'danger' }
      }, status: :unprocessable_content
    end

    @user.send_reset_password_instructions
    render json: { toast: "Password reset email sent to #{@user.email}." }
  rescue StandardError => e
    Rails.logger.error "send_password_reset failed for user #{@user.id}: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    render json: {
      toast: { title: 'Could not send password reset.', message: ['An internal error occurred. Please try again or contact an administrator.'], variant: 'danger' }
    }, status: :internal_server_error
  end

  # Generate a reset token and return the URL without sending email (no SMTP needed)
  def generate_reset_link
    reset_url = generate_reset_url(@user)
    render json: {
      toast: 'Reset link generated. Copy it and deliver to the user.',
      reset_url: reset_url
    }
  end

  # Admin locks a user account
  def lock
    if @user == current_user
      return render json: {
        toast: { title: 'Cannot lock yourself.', message: ['You cannot lock your own account.'], variant: 'danger' }
      }, status: :unprocessable_content
    end

    @user.lock_access!(send_instructions: false)
    @user.audits.create!(action: 'update', audited_changes: { 'locked_at' => [nil, @user.locked_at.iso8601] },
                         user: current_user, comment: "Account locked by #{current_user.name}")
    render json: {
      toast: "Account #{@user.email} locked.",
      user: @user.as_json(only: USER_JSON_FIELDS)
    }
  end

  # Admin unlocks a locked user account
  def unlock
    prev_locked_at = @user.locked_at&.iso8601
    @user.unlock_access!
    @user.audits.create!(action: 'update', audited_changes: { 'locked_at' => [prev_locked_at, nil] },
                         user: current_user, comment: "Account unlocked by #{current_user.name}")
    render json: {
      toast: "Account #{@user.email} unlocked.",
      user: @user.as_json(only: USER_JSON_FIELDS)
    }
  end

  # Admin directly sets user password (no SMTP needed)
  def set_password
    if password_params[:password].blank?
      return render json: {
        toast: { title: 'Password required.', message: ['Password cannot be blank.'], variant: 'danger' }
      }, status: :unprocessable_content
    end

    @user.password = @user.password_confirmation = password_params[:password]
    if @user.save
      render json: { toast: "Password updated for #{@user.email}." }
    else
      render json: {
        toast: { title: 'Could not set password.', message: @user.errors.full_messages, variant: 'danger' }
      }, status: :unprocessable_content
    end
  rescue StandardError => e
    Rails.logger.error "set_password failed for user #{@user.id}: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    render json: {
      toast: { title: 'Could not set password.', message: ['An internal error occurred. Please try again or contact an administrator.'], variant: 'danger' }
    }, status: :internal_server_error
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_create_params
    params.expect(user: %i[name email admin])
  end

  def user_update_params
    params.expect(user: %i[name email admin])
  end

  def password_params
    params.permit(user: [:password])[:user] || {}
  end

  def generate_compliant_password
    # Start with cryptographically random base, then append random chars
    # to guarantee password complexity validator passes (DoD 2222: 2 upper, 2 lower, 2 digits, 2 special)
    base = Devise.friendly_token(20)
    uppers = Array.new(2) { ('A'..'Z').to_a.sample(random: SecureRandom) }.join
    lowers = Array.new(2) { ('a'..'z').to_a.sample(random: SecureRandom) }.join
    digits = Array.new(2) { ('0'..'9').to_a.sample(random: SecureRandom) }.join
    specials = Array.new(2) { '!@#$%^&*()_+-='.chars.sample(random: SecureRandom) }.join
    "#{base}#{uppers}#{lowers}#{digits}#{specials}".chars.shuffle(random: SecureRandom).join
  end

  def generate_reset_url(user)
    raw, hashed = Devise.token_generator.generate(User, :reset_password_token)
    # Skip validations — matches Devise's own save(validate: false) pattern.
    # Token writes carry no business logic and must not be blocked by unrelated
    # validation failures on the user record (e.g., tightened name limits).
    # rubocop:disable Rails/SkipsModelValidations
    user.update_columns(reset_password_token: hashed, reset_password_sent_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
    edit_user_password_url(reset_password_token: raw)
  end
end
