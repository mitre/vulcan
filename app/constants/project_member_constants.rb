# frozen_string_literal: true

# Constants that involve ProjectMember or roles
module ProjectMemberConstants
  PROJECT_MEMBER_ROLES = %w[admin reviewer editor].freeze
  PROJECT_MEMBER_EDITORS = %w[admin reviewer editor].freeze
  PROJECT_MEMBER_REVIEWERS = %w[admin reviewer].freeze
  PROJECT_MEMBER_ADMINS = 'admin'
end
