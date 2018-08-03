#!/usr/local/bin/ruby
# encoding: utf-8
# author: Matthew Dromazos

require 'json'
require 'ripper'
require 'tempfile'
require 'stringio'
require 'util/tar'

class UploadService
  include ActiveModel::Validations
  include Util::Tar
  ###
  #  Creates a project from a InSpec profile in a tarball
  ###
  def upload_project_inspec_tarball(file, current_user)
    puts tar(file.path)
    # cli = Inspec::InspecCLI.new.json(file.path)
  end
  
  ###
  #  Creates a project from repository url containing an InSpec profile
  ###
  def upload_project_url(url)
    
  end
  
  ###
  #  Creates a project from a STIG in an excel file
  ###
  def self.upload_project_excel(file)
    # project_xlsx = Roo::Excelx.new(file.path)
    # project_info = project_xlsx.sheet('Profile').row(2)
    return 1
  end
  
  ###
  #  Creates a project out of an InSpec profile JSON
  ###
  def upload_project_inspec_json(file, current_user)
    puts current_user
    project_json = JSON.parse(File.read(file.path))
    attributes = project_attributes_inspec_json(project_json)
    @project = Project.create!(attributes)
    @project.vendor = Vendor.find(current_user.vendors[0].id)
    @project.users << @project.vendor.users
    @project.save
    project_json['controls'].each do |json_control|
      project_control = @project.project_controls.create(project_control_attr_inspec_json(json_control))
      json_control['tags']['nist'].each do |json_nist| 
        project_control.nist_controls << NistControl.where(family: json_nist.split('-')[0], index: json_nist.split('-')[1])
      end if json_control['tags']['nist']
    end
    return @project
  end
  
  ###
  #  Creates a project out of an STIG XCCDF
  ###
  def self.upload_project_stig_xccdf(file)
    
  end
  
  private
  
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