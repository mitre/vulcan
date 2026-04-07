# frozen_string_literal: true

# Compact user representation for dropdowns, member lists, and available_members.
# Only exposes id, name, email — never passwords, tokens, or admin status.
class UserBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :email
end
