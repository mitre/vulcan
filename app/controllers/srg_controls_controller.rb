class SrgControlsController < ApplicationController
  before_action :set_srg_control, only: [:show, :edit, :update, :destroy]

  # GET /srg_controls
  # GET /srg_controls.json
  def index
    @srg_controls = SrgControl.all
  end

  # GET /srg_controls/1
  # GET /srg_controls/1.json
  def show
  end

  # GET /srg_controls/new
  def new
    @srg_control = SrgControl.new
  end

  # GET /srg_controls/1/edit
  def edit
  end

  # POST /srg_controls
  # POST /srg_controls.json
  def create
    @srg_control = SrgControl.new(srg_control_params)

    respond_to do |format|
      if @srg_control.save
        format.html { redirect_to @srg_control, notice: 'Srg control was successfully created.' }
        format.json { render :show, status: :created, location: @srg_control }
      else
        format.html { render :new }
        format.json { render json: @srg_control.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /srg_controls/1
  # PATCH/PUT /srg_controls/1.json
  def update
    respond_to do |format|
      if @srg_control.update(srg_control_params)
        format.html { redirect_to @srg_control, notice: 'Srg control was successfully updated.' }
        format.json { render :show, status: :ok, location: @srg_control }
      else
        format.html { render :edit }
        format.json { render json: @srg_control.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /srg_controls/1
  # DELETE /srg_controls/1.json
  def destroy
    @srg_control.destroy
    respond_to do |format|
      format.html { redirect_to srg_controls_url, notice: 'Srg control was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_srg_control
      @srg_control = SrgControl.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def srg_control_params
      params.require(:srg_control).permit(:controlId, :severity, :title, :description, :iacontrols, :ruleID, :fixid, :fixtext, :checkid, :checktext)
    end
end
