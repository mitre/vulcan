# frozen_string_literal: true

# Controller for SecurityRequirementsGuides
class SecurityRequirementsGuidesController < ApplicationController
  before_action :authorize_admin, except: %i[index]
  before_action :security_requirements_guide, only: %i[destroy]
  before_action :read_uploaded_file, only: %i[create]

  def index
    @srgs = SecurityRequirementsGuide.all.order(:srg_id, :version).select(:id, :srg_id, :title, :version, :release_date)
    respond_to do |format|
      format.html
      format.json { render json: @srgs }
    end
  end

  def create
    if @upload_errors.empty?
      srg_models = build_srg_from_xml(@upload_contents)
      failed_instances = SecurityRequirementsGuide.import(srg_models, all_or_none: true,
                                                                      recursive: true).failed_instances
      if failed_instances.blank?
        render(json: { toast: "Successfully created #{srg_models.size} SRG." }, status: :ok) and return
      end

      @upload_errors = failed_instances.map { |instance| instance.errors.full_messages }.flatten
    end

    render(json: {
             toast: {
               title: 'Could not create SRG.',
               message: @upload_errors,
               variant: 'danger'
             },
             status: :unprocessable_entity
           })
  end

  def destroy
    if @srg.destroy
      flash.notice = 'Successfully removed SRG.'
    else
      flash.alert = "Unable to remove SRG. #{@srg.errors.full_messages.join(', ')}"
    end
    redirect_to action: 'index'
  end

  private

  def security_requirements_guide
    @srg = SecurityRequirementsGuide.find(params[:id])
  end

  def read_uploaded_file
    file = params.require('file')
    file_name = file.original_filename
    @upload_contents = []
    @upload_errors = []

    if file_name.ends_with?('.xml')
      @upload_contents << file.read
    elsif file_name.ends_with?('.zip')
      Zip::File.open_buffer(file.read) do |zf|
        if zf.all? { |f| f.name.ends_with?('.xml') }
          zf.each do |entry|
            entry.get_input_stream { |io| @upload_contents << io.read }
          end
        else
          @upload_errors << 'Error reading the submitted zip file. Ensure that all files in the zip are XML files.'
        end
      end
    else
      @upload_errors << 'Wrong file type submitted: accepted file type are XML or zip archive of XML files.'
    end
  end

  def build_srg_from_xml(xmls)
    srgs = []
    xmls.each do |xml|
      parsed_benchmark = Xccdf::Benchmark.parse(xml)
      srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
      srg.parsed_benchmark = parsed_benchmark
      srg.xml = xml
      srgs << srg
    end
    srgs
  end
end
