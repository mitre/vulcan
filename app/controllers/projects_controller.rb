class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :edit, :update, :destroy]

  # GET /projects
  # GET /projects.json
  def index
    @projects = Project.all
    respond_to do |format|
      format.html
      format.json  { send_data Project.find(params[:id]), :filename => Project.find(params[:id]).name + '-overview.json' }
    end
  end

  # GET /projects/1
  # GET /projects/1.json
  def show
    respond_to do |format|
      format.html
      format.json { send_data create_project_json(Project.find(params[:id])), :filename => Project.find(params[:id]).name + '-overview.json' }  
    end
  end

  # GET /projects/new
  def new
    @srg_data = fetch_srg_data_families
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
    srg_families = []
    project_params[:srg_ids].each do |srg_id|
      new_srg_id = srg_id.gsub('\"', '"')
      new_srg_id = new_srg_id.gsub(':', '"')
      new_srg_id = new_srg_id.gsub('=>', '":')
      new_srg_id = JSON.parse(new_srg_id)
      srg_families << new_srg_id
    end
    
    respond_to do |format|
      if @project.save
        format.html { redirect_to @project, notice: 'Project was successfully created.' }
        format.json { render :show, status: :created, location: @project }
      else
        format.html { render :new }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
    get_project_controls(srg_families).each do |control|
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
      project_hash = {"project_data" => project, "controls" => JSON.parse(project.controls.to_json)}
      project.controls.each_with_index do |control, i|
        project_hash["controls"][i]["nist_families"] = control.nist_families
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
    
    def get_project_controls(nists)
      controls = []
      nists.each do |nist|
        nist_control = NistControl.find_by(family: nist['family'].split('-')[0], index: nist['family'].split('-')[1])
        srg_controls = SrgControl.joins(:nist_controls).where(srg_controls: {srg_id: nist["srg_id"]}, nist_controls: {id: nist_control.id})
        # srg_controls = SrgControl.find_by(srg_id: nist["srg_id"]).joins(:nist_controls).where(nist_control_id: nist_control.id)
        srg_controls.each do |srg_control|
          puts srg_control.inspect
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
