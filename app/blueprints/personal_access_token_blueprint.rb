# frozen_string_literal: true

# Serializes PersonalAccessToken for the management UI. Default view is the
# token owner's own view; :admin view adds user attribution for admin screens.
class PersonalAccessTokenBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :token_prefix, :scopes, :expires_at, :last_used_at,
         :revoked_at, :allowed_ips, :created_at

  view :admin do
    field :user_id

    field :user_name do |token, _options|
      token.user&.name
    end

    field :user_email do |token, _options|
      token.user&.email
    end
  end
end
