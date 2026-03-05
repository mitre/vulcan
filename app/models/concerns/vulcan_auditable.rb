# frozen_string_literal: true

# Centralized audit configuration for Vulcan models.
#
# Provides `vulcan_audited` as a drop-in replacement for `audited` with
# project-standard defaults:
#   - max_audits: 1000
#   - Auto-excludes created_at and updated_at (unless using `only:`)
#
# Usage:
#   include VulcanAuditable
#   vulcan_audited except: %i[some_field], associated_with: :parent
#
module VulcanAuditable
  extend ActiveSupport::Concern

  class_methods do
    def vulcan_audited(**options)
      options[:max_audits] ||= 1000

      # When using `only:`, don't inject `except:` — they're mutually exclusive
      unless options.key?(:only)
        options[:except] = Array(options[:except]).map(&:to_s) | %w[created_at updated_at]
        options[:except] = options[:except].map(&:to_sym)
      end

      audited(**options)
    end
  end
end
