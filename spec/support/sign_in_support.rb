module ValidUserRequestHelper
  # for use in request specs
  def sign_in_as_a_valid_user
    @user ||= FactoryBot.create :vendor
    post user_session_path, params: { user: { email: @user.email, password: @user.password } }
    follow_redirect!
  end
end

RSpec.configure do |config|
  config.include ValidUserRequestHelper, type: :request
end
