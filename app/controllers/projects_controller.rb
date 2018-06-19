require 'json'
require 'ripper'
class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [:show, :edit, :update, :destroy, :edit_project_controls, :test]
  respond_to :html, :json
  # GET /projects
  # GET /projects.json
  def index  
    @projects = current_user.projects

    respond_to do |format|
      format.html
      format.json  { Project.find(params[:id]) }
      format.csv   { send_data Project.find(params[:id]), :filename => Project.find(params[:id]).name + '-overview.csv' }
    end
  end

  # GET /projects/1
  # GET /projects/1.json
  def show
    respond_to do |format|
      format.html
      format.json { send_data create_project_json(Project.find(params[:id])), :filename => Project.find(params[:id]).name + '-overview.json' }
      format.csv  { send_data Project.find(params[:id]).to_csv, :filename => Project.find(params[:id]).name + '-overview.csv' }
      format.xlsx
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

  # GET /projects/new
  def new
    @srgs = Srg.all
    @project = Project.new
    @users = User.all
  end

  # GET /projects/1/edit
  def edit
    puts @srg_data
  end

  # POST /projects
  # POST /projects.json
  def create
    puts Rails.application.secrets.db.length
    
    project_params[:srg_ids] = project_params[:srg_ids].select {|srg_id| srg_id != "0"} unless project_params[:srg_ids].nil?
    project_params[:users] = project_params[:users].select {|user| user != "0"} unless project_params[:srg_ids].nil?
    @project = Project.new(get_project_json(project_params))
    @project.srgs << Srg.where(title: project_params[:srg_ids])
    @project.users << current_user
    @project.users << User.where(email: project_params[:users])
        
    respond_to do |format|
      puts format
      if @project.save
        format.html { redirect_to @project, notice: 'Project was successfully created.' }
        format.json { render :show, status: :created, location: @project }
      else
        format.html { render :new }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
    get_project_controls(@project.srgs).each do |control|
      project_control = @project.project_controls.create(control[:control_params])
      project_control.nist_controls << control[:nist_params]
    end
  end

  # PATCH/PUT /projects/1
  # PATCH/PUT /projects/1.json
  def update
    respond_to do |format|
      if @project.update(project_params)
        format.html { redirect_to @project, notice: 'Project was successfully updated.' }
        format.json { render :show, status: :ok, location: @project }
      else
        format.html { render :edit }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1
  # DELETE /projects/1.json
  def destroy
    @project.destroy
    respond_to do |format|
      format.html { redirect_to projects_url, notice: 'Project was successfully destroyed.' }
      format.json { head :no_content }
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

  private
  
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
      puts @project.project_controls.collect{|control| control.code}.join(' ')
      return @project.project_controls.collect{|control| control.code}.join("\n") if params['run_all'].include?('1')
      return params['code'] if params['run_all'].include?('1')
      puts @project.project_controls.collect{|control| control.code}.join(' ')
    end
    
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
        version: params[:version]
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
          control[:nist_params]                   = srg_control.nist_controls
                      
          controls << control
        end
      end
      controls
    end
    
    # Use callbacks to share common setup or constraints between actions.
    def set_project
      @project = Project.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def project_params
      params.require(:project).permit(:name, :title, :maintainer, :copyright, :copyright_email, :license, :summary, :version, :sha256, srg_ids:[], users:[])
    end
end
