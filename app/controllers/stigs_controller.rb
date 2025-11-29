# frozen_string_literal: true

# Controller for Stigs
class StigsController < ApplicationController
  before_action :authorize_admin, only: %i[create destroy]
  before_action :set_stig, only: %i[show destroy]

  def index
    @stigs = Stig.order(:stig_id, :version).select(:id, :stig_id, :title, :name, :version, :benchmark_date)
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
      respond_to do |format|
        format.html do
          flash.notice = "Successfully removed #{@stig.title}."
          redirect_to stigs_path
        end
        format.json { render json: { toast: 'Successfully removed STIG' } }
      end
    else
      respond_to do |format|
        format.html do
          flash.alert = "Unable to remove #{@stig.title}. #{@stig.errors.full_messages.join(', ')}"
          redirect_to stigs_path
        end
        format.json do
          render json: {
            toast: {
              title: 'Could not remove STIG.',
              message: @stig.errors.full_messages,
              variant: 'danger'
            }
          }, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_stig
    @stig = Stig.includes(stig_rules: %i[rule_descriptions disa_rule_descriptions checks])
                .find_by(id: params[:id])
    return unless @stig.nil?

    flash[:alert] = 'STIG not found'
    redirect_to stigs_path
  end
end
