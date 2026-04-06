# frozen_string_literal: true

# Controller for SecurityRequirementsGuides
class SecurityRequirementsGuidesController < ApplicationController
  include UploadValidatable

  before_action :authorize_admin, only: %i[create destroy]
  before_action -> { validate_upload(:file, max_size: 50.megabytes, allowed_types: %w[.xml]) }, only: :create
  before_action :authorize_logged_in, only: %i[index show export]
  before_action :security_requirements_guide, only: %i[show destroy export]

  def index
    @srgs = SecurityRequirementsGuide.with_severity_counts.order(:srg_id, :version)
    # Rails automatically renders index.html.haml for HTML, index.json.jbuilder for JSON
  end

  def show
    # Eager load associations for performance
    @srg = SecurityRequirementsGuide.includes(srg_rules: %i[disa_rule_descriptions checks]).find(params[:id])

    respond_to do |format|
      format.html { @srg_json = @srg.to_json(methods: %i[srg_rules], except: [:xml]) }
      format.json # Uses show.json.jbuilder (faster than to_json)
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

  def export
    export_type = params[:type]&.to_sym

    unless %i[xccdf csv].include?(export_type)
      render json: {
        toast: {
          title: 'Export error',
          message: "Unsupported export type: #{export_type}. SRGs can be exported as XCCDF or CSV.",
          variant: 'danger'
        }
      }, status: :bad_request
      return
    end

    respond_to do |format|
      format.html do
        case export_type
        when :xccdf
          filename = "#{@srg.title.tr(' ', '-')}-#{@srg.version}-xccdf.xml"
          send_data @srg.xml, filename: filename, type: 'application/xml'
        when :csv
          columns = parse_csv_columns(params[:columns])
          filename = "#{@srg.title.tr(' ', '-')}-#{@srg.version}.csv"
          send_data @srg.csv_export(columns: columns), filename: filename, type: 'text/csv'
        else
          # Guard validated above; this branch should never be reached
          head :not_acceptable
        end
      end
      format.json { render json: { status: :ok } }
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

  def parse_csv_columns(columns_param)
    return nil if columns_param.blank?

    keys = columns_param.split(',').map(&:strip).map(&:to_sym)
    valid_keys = ExportConstants::BENCHMARK_CSV_COLUMNS.keys
    keys.select { |k| valid_keys.include?(k) }.presence
  end
end
