class RequestsController < ApplicationController
  load_and_authorize_resource
  before_action :set_request, only: [:edit]
  def edit
    if current_user.has_role? :admin
      if params[:request][:action] == 'Approve'
        @request.user.add_role @request.role
        @request.update_attribute(:status, 'Approved')
      else
        @request.update_attribute(:status, 'Denied')
      end
    end
    redirect_to '/'
  end

  def create
    if params['type'] == 'Sponsor'
      create_sponsor(sponsor_params)
    else
      create_vendor(vendor_params)
    end
    redirect_to '/'
  end

  private

  def create_sponsor(sponsor_params)
    if (sponsor = SponsorAgency.where("'sponsor_name' = ? AND 'phone_number' = ? AND 'email' = ? AND 'organization' = ?",
                                      sponsor_params['sponsor_name'],
                                      sponsor_params['phone_number'],
                                      sponsor_params['email'],
                                      sponsor_params['organization']))
      current_user.sponsor_agency = sponsor
    else
      current_user.sponsor_agency = SponsorAgency.new(sponsor_params)
    end
    current_user.requests.create({ status: 'Pending', role: 'sponsor' })
  end

  def create_vendor(vendor_params)
    if (vendor = Vendor.where("'vendor_name' = ? AND 'point_of_contact' = ? AND 'poc_email' = ? AND 'poc_phone_number' = ?",
                              vendor_params['vendor_name'],
                              vendor_params['point_of_contact'],
                              vendor_params['poc_email'],
                              vendor_params['poc_phone_number']))
      current_user.vendor = vendor
    else
      current_user.vendor = Vendor.new(vendor_params)
    end
    current_user.requests.create({ status: 'Pending', role: 'vendor' })
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_request
    @request = Request.find(params[:id])
  end

  # def vendor_params
  #   params.permit(:vendor_name, :point_of_contact, :poc_email, :poc_phone_number)
  # end
  #
  # def sponsor_params
  #   params.permit(:sponsor_name, :phone_number, :email, :organization)
  # end
end
