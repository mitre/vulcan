# frozen_string_literal: true

# Serializes the authenticated user for GET /api/auth/me.
# Includes admin status and provider — fields the SPA needs
# for route guards and UI state but that the default UserBlueprint
# excludes (dropdowns/member lists don't need admin status).
class CurrentUserBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :email, :admin, :provider
end
