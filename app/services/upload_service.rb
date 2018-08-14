#!/usr/local/bin/ruby
# encoding: utf-8
# author: Matthew Dromazos

require 'json'
require 'ripper'
require 'tempfile'
require 'zlib'
require 'open3'
require 'roo'
require 'yaml'

class UploadService
  include ActiveModel::Validations

  ###
  #  Creates a project from a InSpec profile in a tarball
  ###
  def upload_project_inspec_tarball(file, current_user)
    stdout, stderr, status = Open3.capture3("mv #{file.path} #{file.path.split('.')[0]}.tar.gz")
    stdout_json, stderr_json, status_json = Open3.capture3("inspec json #{file.path.split('.')[0]}.tar.gz")
    json = stdout_json.split("\n", 2)[1] == '' ? stdout_json : stdout_json.split("\n", 2)[1]
    return upload_project_inspec_json(JSON.parse(json), current_user)
  end
  
  ###
  #  Creates a project from repository url containing an InSpec profile
  ###
  def upload_project_url(url, current_user)
    stdout, stderr, status = Open3.capture3("inspec json #{url}")
    json = stdout.split("\n", 2)[1]
    return upload_project_inspec_json(JSON.parse(json), current_user)
  end
  
  ###
  #  Creates a project from a STIG in an excel file
  ###
  def upload_project_excel(file, current_user, opts)
    File.open("tmp/mapping.yml", "w") { |file| file.write(opts.to_yaml) }
    xlsx = Roo::Spreadsheet.open(file.path)
    name = file.original_filename.split('.')[0..-2].join('.')
    mapping = YAML.load_file("tmp/mapping.yml")
    csv_tool = InspecTools::CSVTool.new(CSV.parse(xlsx.sheet(0).to_csv, encoding: 'ISO8859-1'), mapping, false, name)
    inspec_json = csv_tool.to_inspec
    return upload_project_inspec_json(inspec_json, current_user)
  end
  
  ###
  #  Creates a project out of an InSpec profile JSON
  ###
  def upload_project_inspec_json_file(file, current_user)
    project_json = JSON.parse(File.read(file.path))
    return upload_project_inspec_json(project_json, current_user)
  end
  
  ###
  #  Creates a project out of an STIG XCCDF
  ###
  def upload_project_stig_xccdf(file, current_user)
    xccdf = File.read(file.path)
    xccdf_tool = InspecTools::XCCDF.new(xccdf)
    project_json = xccdf_tool.to_inspec
    return upload_project_inspec_json(project_json, current_user)
  end
  
  private
  
  ###
  # This method takes in an inspec json file and creates a vulcan project out of it
  ###
  def upload_project_inspec_json(inspec_json, current_user)
    attributes = project_attributes_inspec_json(inspec_json)
    @project = Project.create!(attributes)
    @project.vendor = Vendor.find(current_user.vendors[0].id) unless current_user.vendors.empty?
    @project.sponsor_agency = SponsorAgency.find(current_user.sponsor_agencies[0].id) unless current_user.sponsor_agencies.empty?

    @project.users << @project.vendor.users if @project.vendor
    @project.users << @project.sponsor_agency.users if @project.sponsor_agency
    @project.save
    inspec_json['controls'].each do |json_control|
      project_control = @project.project_controls.create(project_control_attr_inspec_json(json_control))
      json_control['tags']['nist'].each do |json_nist| 
        project_control.nist_controls << NistControl.where(family: json_nist.split('-')[0], index: json_nist.split('-')[1])
      end if json_control['tags']['nist']
    end
    return @project
  end
  
  # untars the given IO into the specified
  # directory
  def untargz(path, destination)
    Gem::Package::TarReader.new( Zlib::GzipReader.open path ) do |tar|
      tar.each do |tarfile|
        destination_file = File.join destination, tarfile.full_name
        
        if tarfile.directory?
          FileUtils.mkdir_p destination_file
        else
          destination_directory = File.dirname(destination_file)
          FileUtils.mkdir_p destination_directory unless File.directory?(destination_directory)
          File.open destination_file, "wb" do |f|
            f.print tarfile.read
          end
        end
      end
    end
  end
  
  def project_attributes_inspec_json(json)
    attributes = {
      name: json['name'],
      title: json['title'],
      maintainer: json['maintainer'],
      copyright: json['copyright'],
      copyright_email: json['copyright_email'],
      license: json['license'],
      summary: json['summary'],
      version: json['version'],
      status: 'approved'
    }
  end
  
  def project_control_attr_inspec_json(json_control)
    attributes = {
      title: json_control['title'],
      description: json_control['desc'],
      impact: json_control['impact'],
      code: json_control['code'],
      control_id: json_control['id'],
      checktext: json_control['tags']['audit'],
      fixtext: json_control['tags']['fix'],
      srg_title_id: json_control['title'],
      applicability: 'Applicable - Configurable',
      status: 'Not Started',
    }
  end
  
end

# if params[:file].content_type == "application/json"
#   begin
#     project_json = JSON.parse(File.read(params[:file].path))
#     @project = Project.create(project_json["project_data"].except('id'))
#     project_json["controls"].each do |control|
#       project_control = @project.project_controls.create(control.except("nist_controls"))
#       control["nist_controls"].each do |nist_control|
#         project_control.nist_controls << NistControl.find(nist_control["id"])
#       end
#     end
#   rescue StandardError => e
#   end
# elsif params[:file].content_type == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
#   begin
#     project_xlsx = Roo::Excelx.new(params[:file].path)
#     project_info = project_xlsx.sheet('Profile').row(2)
#     if detect_upload_project_doesnt_exist(project_info[0])
# 
#     end
#   rescue StandardError => e
# 
#   end
# end
# redirect_to projects_path, notice: 'Project uploaded.'