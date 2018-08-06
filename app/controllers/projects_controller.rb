require 'json'
require 'ripper'
class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [:show, :edit, :update, :destroy, :edit_project_controls, :test, :review_project, :approve_project]
  respond_to :html, :json
  # GET /projects
  # GET /projects.json
  def index  
    
    @projects = current_user.projects.select {|project| project.status != 'pending'}
    @pending_projects = current_user.projects.select {|project| project.status == 'pending'}
    respond_to do |format|
      format.html
      format.json  { Project.find(params[:id]) }
      format.csv   { send_data Project.find(params[:id]), :filename => Project.find(params[:id]).name + '-overview.csv' }
    end
  end

  # GET /projects/1
  # GET /projects/1.json
  def show
    if current_user.has_role?(current_user.roles.first.name, @project)
      respond_to do |format|
        format.html
        # format.json { send_data create_project_json(Project.find(params[:id])), :filename => Project.find(params[:id]).name + '-overview.json' }
        format.csv  { send_data Project.find(params[:id]).to_csv, :filename => Project.find(params[:id]).name + '-overview.csv' }
        format.json { send_data Project.find(params[:id]).to_prof, :filename => Project.find(params[:id]).name + '-overview.zip' }
        format.xlsx
      end
    end
  end
  
  # GET /project_controls/1/edit_controls
  def edit_project_controls
    nist_families = NistFamily.all.collect{|nist| nist.short_title}
    @nist_families = []
    
    @project.project_controls.each do |control|
      control.nist_controls.each do |nist_control|
        if nist_families.include?(nist_control.family)
          nist_family = NistFamily.find(nist_control.nist_families_id)
          @nist_families << nist_family unless @nist_families.include?(nist_family)
        end
      end
    end
  end
  
  # Test /project_controls/1/test_controls
  def test
    project_nist_controls
    if request.xhr?
      if Ripper.sexp(params['code']).nil?
        return "ERROR: SYNTAX"
      end
      @results = run_test(params)
      @results = JSON.parse(@results.to_json) if @results.is_a?(Hash)
      @results = {'controls' => @results['profiles'].first['controls'].collect {|control| control['results']}}.to_json if @results.is_a?(Hash)
      respond_to do |format|
        format.html
        format.js
      end
    else
      project_nist_controls  
    end
  end
  
  # GET /projects/1/review_project
  def review_project
    render partial: 'components/project_review_form', project: @project
  end

  # GET /projects/new
  def new
    @srgs = Srg.all
    @project = Project.new
    @users = User.all
  end

  # GET /projects/1/edit
  def edit
    puts params
    puts @srg_data
  end

  # POST /projects
  # POST /projects.json
  def create
    if current_user.has_role?(:vendor) || current_user.has_role?(:admin) 
      begin
        project_params[:srg_ids] = project_params[:srg_ids].select {|srg_id| srg_id != "0"} unless project_params[:srg_ids].nil?
        project_params[:srg_ids] = project_params[:srg_ids].drop(1) unless project_params[:srg_ids].nil?
        project_params[:users] = project_params[:users].select {|user| user != "0"} unless project_params[:users].nil?
        @project = Project.new(get_project_json(project_params))
        @project.srgs << Srg.where(title: project_params[:srg_ids])
        @project.vendor = Vendor.find(params[:project][:vendor_id])
        @project.sponsor_agency = SponsorAgency.find(params[:project][:sponsor_agency_id])
        
        @project.users << @project.vendor.users
        @project.users << @project.sponsor_agency.users
        respond_to do |format|
          if @project.save!
            puts "here"
            assign_project_to_users
            format.html { redirect_to projects_path, notice: 'Project was successfully created.' }
            format.json { render :show, status: :created, location: @project }
          else
            puts @project.errors.inspect
            format.html { redirect_to projects_path, error: 'Profile was not successfully created.' }
            format.json { render json: @project.errors, status: :unprocessable_entity }
          end
        end
      rescue ActiveRecord::RecordNotFound
        puts @project.errors
        respond_to do |format|
          format.html { redirect_to projects_path, error: 'Profile was not successfully created.' }
          format.json { render json: @project.errors, status: :unprocessable_entity }
        end
      rescue StandardError => e 
        puts e
      end
      # get_project_controls(@project.srgs).each do |control|
      #   project_control = @project.project_controls.create(control[:control_params])
      #   project_control.nist_controls << control[:nist_params]
      #   assign_control_to_users(project_control)
      # end
    end
  end

  # PATCH/PUT /projects/1
  # PATCH/PUT /projects/1.json
  def update
    if current_user.has_role?(current_user.roles.first.name, @project)
      respond_to do |format|
        if @project.update(project_params)
          format.html { redirect_to project_path(@project), notice: 'Project was successfully updated.' }
          format.json { render :show, status: :ok, location: @project }
        else
          format.html { redirect_to edit_project_path(@project), notice: 'Project was not successfully updated.' }
          format.json { render json: @project.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  # DELETE /projects/1
  # DELETE /projects/1.json
  def destroy
    if current_user.has_role?(current_user.roles.first.name, @project)
      @project.destroy
      respond_to do |format|
        format.html { redirect_to projects_path, notice: 'Project was successfully destroyed.' }
        format.json { head :no_content }
      end
    end
  end
  
  # Upload an xlsx or json file and create a project
  def upload
    if params[:file].content_type == "application/json"
      begin
        project_json = JSON.parse(File.read(params[:file].path))
        @project = Project.create(project_json["project_data"].except('id'))
        project_json["controls"].each do |control|
          project_control = @project.project_controls.create(control.except("nist_controls"))
          control["nist_controls"].each do |nist_control|
            project_control.nist_controls << NistControl.find(nist_control["id"])
          end
        end
      rescue StandardError => e
      end
    elsif params[:file].content_type == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      begin
        project_xlsx = Roo::Excelx.new(params[:file].path)
        project_info = project_xlsx.sheet('Profile').row(2)
        if detect_upload_project_doesnt_exist(project_info[0])
          
        end
      rescue StandardError => e
        
      end
    end
    redirect_to projects_path, notice: 'Project uploaded.'
  end
  
  def approve_project
    @project.update_attribute(:status, 'approved')
    puts "project"
    get_project_controls(@project.srgs).each do |control|
      puts "control"
      project_control = @project.project_controls.create(control[:control_params])
      project_control.nist_controls << control[:nist_params]
      assign_control_to_users(project_control)
    end
    redirect_to projects_path, notice: 'Project Approved.'
  end

  private
    def assign_control_to_users(control)
      @project.users.each {|user| user.add_role(user.roles.first.name, control) }
    end
    
    def assign_project_to_users
      @project.users.each {|user| user.add_role(user.roles.first.name, @project) }
    end
  
  
    ###
    # TODO: Add functionality for sudo options.
    # TODO: Test functionality for error handling with incorrect hosts.
    # TODO: Change to create temporary directory and seperate controls
    ###
    def run_test(params)
      runner = get_runner(params)
      code = get_code_to_test(params)
      
      begin
        myfile = File.new("tmp_control.rb", 'w')
        myfile.puts(code)
        myfile.close
        runner.add_target("tmp_control.rb", 'new test suite')
        result = runner.run
        File.delete("tmp_control.rb")
        return runner.report
      rescue ArgumentError, RuntimeError, Train::UserError => e
        return "ERROR: " + e.message
      rescue StandardError => e
        return "ERROR: " + e.message
      end
    end
    
    def get_code_to_test(params)
      return @project.project_controls.collect{|control| control.code}.join("\n") if params['run_all'].include?('1')
      return params['code'] unless params['run_all'].include?('1')
    end
    
    ###
    # TODO: Integrate sudo options
    ###
    def get_runner(params)
      opts = {}
      opts['host']              = params['host'].strip     if params['host']                       != ""
      opts['user']              = params['user'].strip if params['user']                           != ""
      opts['password']          = params['pass'] if params['pass']                                 != ""
      opts['port']              = params['port'].strip if params['port']                           != ""
      opts['backend']           = params['transport_method'].strip
      opts['region']            = params['aws_region'].strip if params['region']                       != ''
      opts['access_key_id']     = params['access_key_id'].strip if params['access_key_id']         != ''
      opts['secret_access_key'] = params['secret_access_key'].strip if params['secret_access_key'] != ''
      opts['reporter'] = ['json']
      runner = params['backend'] == 'Local' ? ::Inspec::Runner.new({'color' => true}) : ::Inspec::Runner.new(opts)
    end
  
    def project_nist_controls
      nist_families = NistFamily.all.collect{|nist| nist.short_title}
      @nist_families = []
      
      @project.project_controls.each do |control|
        control.nist_controls.each do |nist_control|
          if nist_families.include?(nist_control.family)
            nist_family = NistFamily.find(nist_control.nist_families_id)
            @nist_families << nist_family unless @nist_families.include?(nist_family)
          end
        end
      end
    end
  
    def detect_upload_project_doesnt_exist(project_name)
      Project.all.select {|project| project.title == project_name}.empty?
    end
  
    def fetch_srg_data_families
      srg_data = {}
      srgs = Srg.all
      srgs.each do |srg|
        srg_controls = srg.srg_controls.all
        srg_data[srg.id] = {}
        srg_data[srg.id][:title] = srg.title
        srg_data[srg.id][:families] = []
        srg_controls.each do |srg_control|
          srg_control.nist_controls.each do |nist_control|
            nist_family_control = NistFamily.find(nist_control.nist_families_id).short_title + '-' + nist_control.index
            srg_data[srg.id][:families] << nist_family_control unless srg_data[srg.id][:families].include?(nist_family_control)
          end
        end
      end
      srg_data
    end
  
    def create_project_json(project)
      project_hash = {"project_data" => project, 
        "controls" => JSON.parse(project.project_controls.to_json)
      }
      project.project_controls.each_with_index do |project_control, i|
        project_hash["controls"][i]["nist_controls"] = project_control.nist_controls
      end
      
      project_hash.to_json
    end
  
    def get_project_json(params)
      new_params = {
        name: params[:name],
        title: params[:title],
        maintainer: params[:maintainer],
        copyright: params[:copyright],
        copyright_email: params[:copyright_email],
        license: params[:license],
        summary: params[:summary],
        version: params[:version],
        status: 'pending'
      }
    end
    
    def get_project_controls(srgs)
      controls = []
      srgs.each do |srg|
        srg.srg_controls.each do |srg_control|
          control = {control_params: {}}
          control[:control_params][:title]        = srg_control.title
          control[:control_params][:description]  = srg_control.description
          control[:control_params][:impact]       = srg_control.severity
          control[:control_params][:control_id]   = srg_control.control_id
          control[:control_params][:srg_title_id] = srg_control.srg_title_id
          control[:control_params][:checktext]    = srg_control.checktext
          control[:control_params][:fixtext]      = srg_control.fixtext
          control[:control_params][:status]       = 'Not Started'
          control[:nist_params]                   = srg_control.nist_controls
                      
          controls << control
        end
      end
      controls
    end
    
    # Use callbacks to share common setup or constraints between actions.
    # Only give the project if the user has a role to that project
    def set_project
      @project = Project.find(params[:id]) if current_user.has_role?(:vendor, Project.find(params[:id])) || current_user.has_role?(:sponsor, Project.find(params[:id])) ||
                                              current_user.has_role?(:admin, Project.find(params[:id]))
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def project_params
      params.require(:project).permit(:name, :title, :maintainer, :copyright, :copyright_email, :license, :summary, :version, :sha256, srg_ids:[], users:[])
    end
end
