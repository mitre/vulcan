# frozen_string_literal: true

# User serialization with view-specific field sets.
# default — compact (dropdowns, member lists, navbar notifications): id, name, email
# :admin — admin management: adds provider, admin, sign-in, lockout fields
class UserBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :email

  view :profile do
    fields :provider, :slack_user_id, :unconfirmed_email

    field :identities do |user|
      user.identities.order(last_sign_in_at: :desc).map do |i|
        { id: i.id, provider: i.provider, email: i.email,
          title: OidcProviderRegistry.title_for(i.provider),
          last_sign_in_at: i.last_sign_in_at&.iso8601,
          can_unlink: user.can_unlink?(i) }
      end
    end

    field :connectable_providers do |user|
      linked = user.identities.pluck(:provider)
      Devise.omniauth_providers.filter_map do |p|
        name = p.to_s
        next if linked.include?(name)

        { name: name, title: OidcProviderRegistry.title_for(name) }
      end
    end
  end

  view :admin do
    fields :provider, :admin, :last_sign_in_at, :failed_attempts, :locked_at

    field :identities do |user|
      user.identities.order(last_sign_in_at: :desc).map do |i|
        { provider: i.provider, email: i.email,
          title: OidcProviderRegistry.title_for(i.provider),
          last_sign_in_at: i.last_sign_in_at&.iso8601 }
      end
    end
  end
end
