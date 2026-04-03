# frozen_string_literal: true

module Import
  module JsonArchive
    # Imports project memberships from backup JSON. Resolves user by email
    # (fallback: name). Skips if user not found or membership already exists.
    class MembershipBuilder
      def initialize(memberships_data, project, result)
        @memberships_data = memberships_data || []
        @project = project
        @result = result
      end

      def build_all
        count = 0
        @memberships_data.each do |membership_data|
          user = resolve_user(membership_data)
          unless user
            @result.add_warning(
              "Membership: user '#{membership_data['email'] || membership_data['name']}' not found. Skipped."
            )
            next
          end

          if Membership.exists?(user: user, membership: @project, membership_type: 'Project')
            @result.add_warning(
              "Membership: user '#{user.email}' is already a member of this project. Skipped."
            )
            next
          end

          Membership.create!(
            user: user,
            membership: @project,
            role: membership_data['role'] || 'viewer'
          )
          count += 1
        end
        count
      end

      private

      def resolve_user(data)
        email = data['email']
        return User.find_by(email: email) if email.present?

        name = data['name']
        return User.find_by(name: name) if name.present?

        nil
      end
    end
  end
end
