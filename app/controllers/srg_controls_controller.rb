class SrgControlsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_srg_control, only: [:show, :edit, :update, :destroy, :review_srg_control]
  
  # GET /srg_controls
  # GET /srg_controls.json
  def index
    @srg = Srg.find(params[:srg_id])
    @srg_controls = SrgControl.all
  end

  # GET /srg_controls/1
  # GET /srg_controls/1.json
  def show
  end

  # GET /srg_controls/new
  def new
    @srg = Srg.find(params[:srg_id])
    @srg_control = @srg.srg_controls.new(control_params)
  end

  # GET /srg_controls/1/edit
  def edit
  end
  
  # # GET /srg_controls/1/review_srg_control
  # def review_srg_control
  #   render partial: 'srg_controls/show'
  # end

  # POST /srg_controls
  # POST /srg_controls.json
  def create
    @srg = Srg.find(params[:srg_id])
    @srg_control = @srg.srg_controls.new(get_srg_control_hash(params))
    get_nist_families.each do |nist_params|
      @srg_control.nist_familys.create(nist_params)
    end

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
    
    def get_srg_control_hash(params)
      {
        id: params[:id],
        srg_id: params[:srg_id],
        project_id: params[:profile_id],
        controlId: params[:profile_id],
        severity: params[:severity],
        title: params[:title],
        description: params[:description],
        ruleID: params[:ruleID],
        fixid: params[:fixid],
        fixtext: params[:fixtext],
        checkid: params[:checkid],
        checktext: params[:checktext]
      }
    end
    
    def get_nist_families(params)
      nist = []
      params[:nistFamily].each do |nist|
        nist << {family: nist[0], version: nist[1].split('_')[1]}
      end
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def srg_control_params
      params.require(:srg_control).permit(:id, :srg_id, :profile_id, :controlId, :severity, :title, :description, :ruleID, :fixid, :fixtext, :checkid, :checktext)
    end
end
