require 'inspec/objects'

class ProjectControlsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project_control, only: [:show, :edit, :update, :destroy, :review_control, :run_test, :update_code]
  respond_to :html, :json

  # GET /controls
  # GET /controls.json
  def index
    # @project_controls = ProjectControl.all
  end

  # GET /project_controls/1
  # GET /project_controls/1.json
  def show
    respond_to do |format|
      format.html
      format.json  { render json: ProjectControl.find(params[:id]) }
    end
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
  
  # GET /project_controls/1/review_control
  def review_control
    render partial: 'review_control_form', project_control: @project_control
  end
  
  def link_control
    link = params[:link]
    control = ProjectControl.find(params[:control_id])
    parent_control = params[:parent_id].empty? ? nil : ProjectControl.find(params[:parent_id])
    
    control.update_attribute(:applicability, '') if link == 'false'
    return control.update_attribute(:parent, nil) if link == 'false'
    
    control.update_attribute(:applicability, parent_control.applicability)
    return control.update_attribute(:parent, parent_control)
  end

  # POST /project_controls
  # POST /project_controls.json
  def create
    if current_user.has_role?(:vendor) || current_user.has_role(:admin)
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
  end

  # PATCH/PUT /project_controls/1
  # PATCH/PUT /project_controls/1.json
  def update
    respond_to do |format|
      if @project_control.update(project_controls_params) && 
         @project_control.update_attribute(:code, params[:code]) && 
         @project_control.update_attribute(:status, 'Awaiting Review') &&
         @project_control.children.each {|child| child.update_attribute(:applicability, @project_control.applicability)}
        format.html { redirect_to project_edit_controls_path(@project_control.project_id), notice: 'Control was successfully updated.' }
        format.json { render :show, status: :ok, location: @project_control }
      else
        format.html { render :edit }
        format.json { render json: @project_control.errors, status: :unprocessable_entity }
      end
    end
  end
  
  def update_code
    if @project_control.update_attribute(:code, params[:code])
      render json: @project_control
    else
      redner json: @project_control.errors
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
      @project_control = ProjectControl.find(params[:id]) if current_user.has_role?(:vendor, ProjectControl.find(params[:id])) || current_user.has_role?(:sponsor, ProjectControl.find(params[:id])) ||
                                                          current_user.has_role?(:admin, ProjectControl.find(params[:id]))
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def project_controls_params
      params.require('project_control').permit(:title, :justification, :applicability, :description, :impact, :code, :control_id, :sl_ref, :sl_line, :srg_title_id, :nist_families, :checktext, :fixtext, :parent_id)
    end
end
