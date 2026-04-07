# frozen_string_literal: true

# Replaces Membership#as_json which added `methods: [:name, :email]`.
class MembershipBlueprint < Blueprinter::Base
  identifier :id

  fields :user_id, :role, :membership_type, :membership_id

  # Delegated from user — avoids N+1 when user is eager-loaded via
  # the has_many :memberships, -> { includes :user } scope
  field :name do |membership, _options|
    membership.user&.name
  end

  field :email do |membership, _options|
    membership.user&.email
  end
end
