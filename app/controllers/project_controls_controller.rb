class ProjectControlsController < ApplicationController
  before_action :set_project_control, only: [:show, :edit, :update, :destroy]

  # GET /controls
  # GET /controls.json
  def index
    @project_controls = ProjectControl.all
  end

  # GET /project_controls/1
  # GET /project_controls/1.json
  def show
  end

  # GET /controls/new
  def new
    @project = Project.find(params[:project_id])
    authorize! :create, @project
    @project_control = @project.controls.new()
  end

  # GET /project_controls/1/edit
  def edit
  end

  # POST /project_controls
  # POST /project_controls.json
  def create
    @project = project.find(params[:project_id])
    authorize! :create, @project
    @project_control = @project.project_controls.new(project_controls_params)

    respond_to do |format|
      if @project_control.save
        format.html { redirect_to @project_control, notice: 'Control was successfully created.' }
        format.json { render :show, status: :created, location: @project_control }
      else
        format.html { render :new }
        format.json { render json: @project_control.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /project_controls/1
  # PATCH/PUT /project_controls/1.json
  def update
    puts project_controls_params
    respond_to do |format|
      if @project_control.update(project_controls_params)
        format.html { redirect_to @project_control, notice: 'Control was successfully updated.' }
        format.json { render :show, status: :ok, location: @project_control }
      else
        format.html { render :edit }
        format.json { render json: @project_control.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /project_controls/1
  # DELETE /project_controls/1.json
  def destroy
    @project_control.destroy
    respond_to do |format|
      format.html { redirect_to project_controls_url, notice: 'Control was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_project_control
      @project_control = ProjectControl.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def project_controls_params
      params.require('project_control').permit(:title, :justification, :status, :description, :impact, :code, :control_id, :sl_ref, :sl_line, :srg_title_id, :nist_families, :checktext, :fixtext)
    end
end
