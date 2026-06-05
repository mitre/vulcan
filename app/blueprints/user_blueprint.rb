# frozen_string_literal: true

# User serialization with view-specific field sets.
# default — compact (dropdowns, member lists, navbar notifications): id, name, email
# :admin — admin management: adds provider, admin, sign-in, lockout fields
class UserBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :email

  view :profile do
    fields :provider, :slack_user_id, :unconfirmed_email
  end

  view :admin do
    fields :provider, :admin, :last_sign_in_at, :failed_attempts, :locked_at
  end
end
