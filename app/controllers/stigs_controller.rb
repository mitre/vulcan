# frozen_string_literal: true

# Controller for Stigs
class StigsController < ApplicationController
  before_action :authorize_admin, only: %i[create destroy]
  before_action :set_stig, only: %i[show destroy]

  def index
    @stigs = Stig.all.order(:stig_id, :version).select(:id, :stig_id, :title, :version, :benchmark_date)
    respond_to do |format|
      format.html
      format.json { render json: @stigs }
    end
  end

  def show
    @stig_json = @stig.to_json(methods: %i[stig_rules])
    respond_to do |format|
      format.html
      format.json { render json: @stig_json }
    end
  end

  def create
    file = params.require('file')
    parsed_benchmark = Xccdf::Benchmark.parse(file.read)
    stig = Stig.from_mapping(parsed_benchmark)
    file.tempfile.seek(0)
    stig.xml = file.read
    if stig.save
      render(json: { toast: "Successfully added #{stig.title}." }, status: :ok)
    else
      render(json: {
               toast: {
                 title: 'Could not add STIG.',
                 message: stig.errors.full_messages,
                 variant: 'danger'
               },
               status: :unprocessable_entity
             })
    end
  end

  def destroy
    if @stig.destroy
      flash.notice = "Successfully removed #{@stig.title}."
    else
      flash.alert = "Unable to remove #{@stig.title}. #{@stig.errors.full_messages.join(', ')}"
    end
    redirect_to stigs_path
  end

  private

  def set_stig
    @stig = Stig.find_by(id: params[:id])
    return unless @stig.nil?

    flash[:alert] = 'STIG not found'
    redirect_to stigs_path
  end
end
