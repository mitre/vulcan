class SponsorAgenciesController < ApplicationController
  # POST /sponsor_agencies
  # POST /sponsor_agencies.json
  def create
    if current_user.has_role? :admin
      @sponsor = SponsorAgency.new(sponsor_agency_params)
      respond_to do |format|
        if @sponsor.save
          format.html { redirect_to "/", notice: 'sponsor was successfully created.' }
          format.json { render :show, status: :created, location: @sponsor }
        else
          format.html { render :new }
          format.json { render json: @sponsor.errors, status: :unprocessable_entity }
        end
      end
    end
  end
  private
  # Never trust parameters from the scary internet, only allow the white list through.
  def sponsor_agency_params
    params.require(:sponsor_agency).permit(:sponsor_name, :organization, :email, :phone_number)
  end
end
