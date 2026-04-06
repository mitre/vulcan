# frozen_string_literal: true

# Controller for Stigs
class StigsController < ApplicationController
  include UploadValidatable

  before_action :authorize_admin, only: %i[create destroy]
  before_action -> { validate_upload(:file, max_size: 50.megabytes, allowed_types: %w[.xml]) }, only: :create
  before_action :authorize_logged_in, only: %i[index show export]
  before_action :set_stig, only: %i[show destroy export]

  def index
    @stigs = Stig.with_severity_counts.order(:stig_id, :version)
    # Rails automatically renders index.html.haml for HTML, index.json.jbuilder for JSON
  end

  def show
    # Eager load associations for performance (set_stig loads basic STIG)
    @stig = Stig.includes(stig_rules: %i[disa_rule_descriptions checks]).find(params[:id])

    respond_to do |format|
      format.html { @stig_json = @stig.to_json(methods: %i[stig_rules], except: [:xml]) }
      format.json # Uses show.json.jbuilder (faster than to_json)
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

  def export
    export_type = params[:type]&.to_sym

    unless %i[xccdf csv].include?(export_type)
      render json: {
        toast: {
          title: 'Export error',
          message: "Unsupported export type: #{export_type}. STIGs can be exported as XCCDF or CSV.",
          variant: 'danger'
        }
      }, status: :bad_request
      return
    end

    respond_to do |format|
      format.html do
        case export_type
        when :xccdf
          filename = "#{@stig.title.tr(' ', '-')}-#{@stig.version}-xccdf.xml"
          send_data @stig.xml, filename: filename, type: 'application/xml'
        when :csv
          columns = parse_csv_columns(params[:columns])
          filename = "#{@stig.title.tr(' ', '-')}-#{@stig.version}.csv"
          send_data @stig.csv_export(columns: columns), filename: filename, type: 'text/csv'
        else
          # Guard validated above; this branch should never be reached
          head :not_acceptable
        end
      end
      format.json { render json: { status: :ok } }
    end
  end

  def destroy
    if @stig.destroy
      respond_to do |format|
        format.html do
          flash.notice = "Successfully removed #{@stig.title}."
          redirect_to stigs_path
        end
        format.json { render json: { toast: "Successfully removed #{@stig.title}." } }
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
    @stig = Stig.find_by(id: params[:id])
    return unless @stig.nil?

    flash[:alert] = 'STIG not found'
    redirect_to stigs_path
  end

  def parse_csv_columns(columns_param)
    return nil if columns_param.blank?

    keys = columns_param.split(',').map(&:strip).map(&:to_sym)
    valid_keys = ExportConstants::BENCHMARK_CSV_COLUMNS.keys
    keys.select { |k| valid_keys.include?(k) }.presence
  end
end
