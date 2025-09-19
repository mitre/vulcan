# frozen_string_literal: true

# Controller for SecurityRequirementsGuides
class SecurityRequirementsGuidesController < ApplicationController
  before_action :authorize_admin, except: %i[index]
  before_action :security_requirements_guide, only: %i[destroy]

  def index
    @srgs = SecurityRequirementsGuide.order(:srg_id, :version).select(:id, :srg_id, :title, :version, :release_date)
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
      send_slack_notification(:upload_srg, srg) if Settings.slack.enabled
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
      send_slack_notification(:remove_srg, @srg) if Settings.slack.enabled

      respond_to do |format|
        format.html do
          flash.notice = 'Successfully removed SRG.'
          redirect_to action: 'index'
        end
        format.json { render json: { toast: 'Successfully removed SRG' } }
      end
    else
      respond_to do |format|
        format.html do
          flash.alert = "Unable to remove SRG. #{@srg.errors.full_messages.join(', ')}"
          redirect_to action: 'index'
        end
        format.json do
          render json: {
            toast: {
              title: 'Could not remove SRG.',
              message: @srg.errors.full_messages,
              variant: 'danger'
            }
          }, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def security_requirements_guide
    @srg = SecurityRequirementsGuide.find(params[:id])
  end
end
