class VendorsController < ApplicationController
  # POST /vendors
  # POST /vendors.json
  def create
    if current_user.has_role? :admin
      @vendor = Vendor.new(vendor_params)
      respond_to do |format|
        if @vendor.save
          format.html { redirect_to "/", notice: 'vendor was successfully created.' }
          format.json { render :show, status: :created, location: @vendor }
        else
          format.html { render :new }
          format.json { render json: @vendor.errors, status: :unprocessable_entity }
        end
      end
    end
  end
  
  private
  
  # Never trust parameters from the scary internet, only allow the white list through.
  def vendor_params
    params.require(:vendor).permit(:vendor_name, :point_of_contact, :poc_email, :poc_phone_number)
  end
end
