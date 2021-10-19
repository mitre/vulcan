# frozen_string_literal: true

# Constants that involve ProjectMember or roles
module ProjectMemberConstants
  PROJECT_MEMBER_ROLES = %w[viewer author reviewer admin].freeze
  PROJECT_MEMBER_VIEWERS = %w[viewer author reviewer admin].freeze
  PROJECT_MEMBER_AUTHORS = %w[author reviewer admin].freeze
  PROJECT_MEMBER_REVIEWERS = %w[reviewer admin].freeze
  PROJECT_MEMBER_ADMINS = 'admin'
end
