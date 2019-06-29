class UsersController < ApplicationController
  # authorize_resource only: [:index, :show, :edit, :destroy, :upload, :image]
  before_action :set_user, only: [:show, :edit, :update, :destroy, :add_role, :remove_role]
  before_action :rotate, only: :update
  before_action :must_be_admin, only: [:index, :add_role, :remove_role]

  # GET /users
  # GET /users.json
  def index
    @users = User.all
  end

  # GET /users/1
  # GET /users/1.json
  def show
  end

  # GET /users/new
  def new
    @user = User.new
  end

  # GET /users/1/edit
  def edit
  end

  # POST /users
  # POST /users.json
  def create
    @user = User.new(user_params)

    respond_to do |format|
      if @user.save
        format.html { redirect_to user_url(@user), notice: 'User was successfully created.' }
        format.json { render :show, status: :created, location: @user }
      else
        format.html { render :new }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def add_role
    role = params[:user][:role].to_sym
    role_user = User.find(params[:user_id])
    role_user.add_role(role)
    redirect_to users_url, notice: 'Role was added.'
  end

  def remove_role
    role_user = User.find(params[:user_id])
    role = params[:role].to_sym
    role_user.remove_role(role)
    redirect_to users_url, notice: 'Role was deleted.'
  end

  def rotate
    rotate = params[:user].delete(:rotate)
    logger.debug "rotate = #{rotate}"
    ImageUploader.rotation = rotate.to_f
    Rails.logger.debug "ROTATION = #{ImageUploader.rotation}"
  end

  # PATCH/PUT /users/1
  # PATCH/PUT /users/1.json
  def update
    respond_to do |format|
      if @user.update(user_params)
        format.html { redirect_to user_url(@user), notice: 'User was successfully updated.' }
        format.json { render :show, status: :ok, location: @user }
      else
        format.html { render :edit }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /users/1
  # DELETE /users/1.json
  def destroy
    @user.destroy
    respond_to do |format|
      format.html { redirect_to users_url, notice: 'User was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def new_session
    @db_user = DbUser.new
    @ldap_user = LdapUser.new
  end

  def image
    content = @user.image.read
    if stale?(etag: content, last_modified: @user.updated_at.utc, public: true)
      send_data content, type: @user.image.file.content_type, disposition: 'inline'
      expires_in 0, public: true
    end
  end

  def set_role
    if current_user.has_role? :admin
      user = User.find(params['user_id'])
      if !user.roles.blank?
        user.remove_role user.roles.first.name
      end
      user.add_role params['org'].split('-')[1]
      user.vendors << Vendor.find(params['org'].split('-')[0]) if params['org'].split('-')[1] == 'vendor'
      user.sponsor_agencies << SponsorAgency.find(params['org'].split('-')[0]) if params['org'].split('-')[1] == 'sponsor'
      redirect_to '/'
    end
  end

  private

  def must_be_admin
    unless current_user&.has_role?(:admin)
      redirect_to root_url, notice: 'Must be admin to access Users page'
    end
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_user
    @user = User.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def user_params
    params.require(:user).permit(:first_name, :last_name, :image, :api_key, :rotate, :role)
  end
end
