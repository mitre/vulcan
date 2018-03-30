class ControlsController < ApplicationController
  before_action :set_control, only: [:show, :edit, :update, :destroy]

  # GET /controls
  # GET /controls.json
  def index
    @controls = Control.all
  end

  # GET /controls/1
  # GET /controls/1.json
  def show
  end

  # GET /controls/new
  def new
    @profile = Profile.find(params[:profile_id])
    authorize! :create, @profile
    @control = @profile.controls.new()
  end

  # GET /controls/1/edit
  def edit
  end

  # POST /controls
  # POST /controls.json
  def create
    @profile = Profile.find(params[:profile_id])
    authorize! :create, @profile
    @control = @profile.controls.new(control_params)

    respond_to do |format|
      if @control.save
        format.html { redirect_to @control, notice: 'Control was successfully created.' }
        format.json { render :show, status: :created, location: @control }
      else
        format.html { render :new }
        format.json { render json: @control.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /controls/1
  # PATCH/PUT /controls/1.json
  def update
    respond_to do |format|
      if @control.update(control_params)
        format.html { redirect_to @control, notice: 'Control was successfully updated.' }
        format.json { render :show, status: :ok, location: @control }
      else
        format.html { render :edit }
        format.json { render json: @control.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /controls/1
  # DELETE /controls/1.json
  def destroy
    @control.destroy
    respond_to do |format|
      format.html { redirect_to controls_url, notice: 'Control was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_control
      @control = Control.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def control_params
      params.require(:control).permit(:title, :description, :impact, :code, :control_id, :sl_ref, :sl_line, :srg_title_id, :nist_families, :checktext, :fixtext)
    end
end
