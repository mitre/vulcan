class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :edit, :update, :destroy]

  # GET /projects
  # GET /projects.json
  def index
    @projects = Project.all
    respond_to do |format|
      format.html
      format.json  { send_data Project.find(params[:id]), :filename => Project.find(params[:id]).name + '-overview.json' }
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

    end
  end

  # GET /projects/new
  def new
    @srgs = Srg.all
    @project = Project.new
  end

  # GET /projects/1/edit
  def edit
    puts @srg_data
  end

  # POST /projects
  # POST /projects.json
  def create
    project_params[:srg_ids] = project_params[:srg_ids].select {|srg_id| srg_id != "0"}
    @project = Project.new(get_project_hash(project_params))
    puts Srg.where(id: project_params[:srg_ids])
    @project.srgs << Srg.where(id: project_params[:srg_ids])
        
    respond_to do |format|
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
  
  def upload
    project_json = JSON.parse(File.read(params[:file].path))
    @project = Project.create(project_json["project_data"].except('id'))
    project_json["controls"].each do |control|
      project_control = @project.project_controls.create(control.except("nist_controls"))
      control["nist_controls"].each do |nist_control|
        project_control.nist_controls << NistControl.find(nist_control["id"])
      end
    end
    redirect_to projects_path, notice: 'Project uploaded.'
  end

  private
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
  
    def get_project_hash(params)
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
          control[:control_params][:title] = srg_control.title
          control[:control_params][:description] = srg_control.description
          control[:control_params][:impact] = srg_control.severity
          control[:control_params][:control_id] = srg_control.control_id
          control[:control_params][:srg_title_id] = srg_control.srg_title_id
          control[:control_params][:checktext] = srg_control.checktext
          control[:control_params][:fixtext] = srg_control.fixtext
          control[:nist_params] = srg_control.nist_controls
          
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
      params.require(:project).permit(:name, :title, :maintainer, :copyright, :copyright_email, :license, :summary, :version, :sha256, srg_ids:[])
    end
end
