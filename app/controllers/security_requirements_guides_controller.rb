# frozen_string_literal: true

# Controller for SecurityRequirementsGuides
class SecurityRequirementsGuidesController < ApplicationController
  include SlackNotificationsHelper
  before_action :authorize_admin, except: %i[index]
  before_action :security_requirements_guide, only: %i[destroy]

  def index
    @srgs = SecurityRequirementsGuide.all.order(:srg_id, :version).select(:id, :srg_id, :title, :version, :release_date)
    respond_to do |format|
      format.html
      format.json { render json: @srgs }
    end
  end

  def create
    file = params.require('file')
    parsed_benchmark = Xccdf::Benchmark.parse(file.read)
    srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    file.tempfile.seek(0)
    srg.parsed_benchmark = parsed_benchmark
    srg.xml = file.read
    if srg.save
      if Settings.slack.enabled
        send_notification(
          Settings.slack.channel_id,
          slack_notification_params(:create_srg, srg)
        )
      end
      render(json: { toast: 'Successfully created SRG.' }, status: :ok)
    else
      render(json: {
               toast: {
                 title: 'Could not create SRG.',
                 message: srg.errors.full_messages,
                 variant: 'danger'
               },
               status: :unprocessable_entity
             })
    end
  end

  def destroy
    if @srg.destroy
      flash.notice = 'Successfully removed SRG.'
      if Settings.slack.enabled
        send_notification(
          Settings.slack.channel_id,
          slack_notification_params(:remove_srg, @srg)
        )
      end
    else
      flash.alert = "Unable to remove SRG. #{@srg.errors.full_messages.join(', ')}"
    end
    redirect_to action: 'index'
  end

  private

  def security_requirements_guide
    @srg = SecurityRequirementsGuide.find(params[:id])
  end

  def slack_notification_params(notification_type, srg)
    notification_type_prefix = notification_type.to_s.match(/^(create|remove)/)[1]
    fields = [
      GENERAL_NOTIFICATION_FIELDS[:generate_app_label],
      SRG_NOTIFICATION_FIELDS[:generate_srg_name_label],
      SRG_NOTIFICATION_FIELDS[:generate_srg_version_label],
      SRG_NOTIFICATION_FIELDS[:generate_initiated_by_label]
    ]
    header = case notification_type
             when :create_srg
               'Vulcan New SRG (Security Requirement Guide) Upload'
             when :remove_srg
               'Vulcan SRG (Security Requirement Guide) Removal'
             end
    {
      icon: case notification_type
            when :create_srg
              ':white_check_mark:'
            when :remove_srg
              ':x:'
            end,
      header: header,
      fields: fields.map do |field|
        label, value = field.values_at(:label, :value)
        label_content = label.respond_to?(:call) ? label.call(notification_type_prefix) : label
        value_content = value.respond_to?(:call) ? value.call(srg, current_user) : value
        { label: label_content, value: value_content }
      end
    }
  end
end
