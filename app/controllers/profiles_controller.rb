class ProfilesController < ApplicationController
  before_action :set_profile, only: [:show, :edit, :update, :destroy, :edit_profile_controls]

  # GET /profiles
  # GET /profiles.json
  def index
    @profiles = Profile.all
  end

  # GET /profiles/1
  # GET /profiles/1.json
  def show
  end

  # GET /profiles/new
  def new
    @srg_data = fetch_srg_data_families
    @srgs = Srg.all
    @profile = Profile.new
  end

  # GET /profiles/1/edit
  def edit
    puts @srg_data
  end

  # POST /profiles
  # POST /profiles.json
  def create
    profile_params[:srg_ids] = profile_params[:srg_ids].select {|srg_id| srg_id != "0"}
    @profile = Profile.new(profile_params)
    profile_params[:srg_ids].each do |srg_id|
      new_srg_id = srg_id.gsub('\"', '"')
      new_srg_id = new_srg_id.gsub(':', '"')
      new_srg_id = new_srg_id.gsub('=>', '":')
      new_srg_id = JSON.parse(new_srg_id)
      
    end

    respond_to do |format|
      if @profile.save
        format.html { redirect_to @profile, notice: 'Profile was successfully created.' }
        format.json { render :show, status: :created, location: @profile }
      else
        format.html { render :new }
        format.json { render json: @profile.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /profiles/1
  # PATCH/PUT /profiles/1.json
  def update
    respond_to do |format|
      if @profile.update(profile_params)
        format.html { redirect_to @profile, notice: 'Profile was successfully updated.' }
        format.json { render :show, status: :ok, location: @profile }
      else
        format.html { render :edit }
        format.json { render json: @profile.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /profiles/1
  # DELETE /profiles/1.json
  def destroy
    @profile.destroy
    respond_to do |format|
      format.html { redirect_to profiles_url, notice: 'Profile was successfully destroyed.' }
      format.json { head :no_content }
    end
  end
  
  def fetch_srg_data_families
    srg_data = {}
    srgs = Srg.all
    srgs.each do |srg|
      srg_controls = srg.srg_controls.all
      srg_data[srg.title] = []
      srg_controls.each do |srg_control|
        srg_control.nist_families.each do |nist|
          srg_data[srg.title] << nist.family unless srg_data[srg.title].include?(nist.family)
        end
      end
    end
    srg_data
  end



  private
    # Use callbacks to share common setup or constraints between actions.
    def set_profile
      @profile = Profile.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def profile_params
      params.require(:profile).permit(:name, :title, :maintainer, :copyright, :copyright_email, :license, :summary, :version, :sha256, srg_ids:[])
    end
end
