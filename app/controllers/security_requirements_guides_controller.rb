# frozen_string_literal: true

class SecurityRequirementsGuidesController < ApplicationController
  before_action :get_security_requirements_guide, only: %i[destroy]

  def index
    @srgs = SecurityRequirementsGuide.all.select(:id, :srg_id, :title, :version)
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
    srg.xml = file.read
    if srg.save
      render(json: { notice: 'Successfully created SRG.'}, status: :ok)
    else
      render(json: { alert: "Could not create SRG. #{srg.errors.full_messages.join(', ')}" }, status: :unprocessable_entity)
    end
  end

  def destroy
    if @srg.destroy
      flash.notice = 'Successfully removed SRG.'
    else
      flash.alert = "Unable to remove SRG. #{@project_member.errors.full_messages}"
    end
    redirect_to action: 'index'
  end

  private

  def get_security_requirements_guide
    @srg = SecurityRequirementsGuide.find(params[:id])
  end
end
