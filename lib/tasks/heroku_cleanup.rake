# frozen_string_literal: true

# Remove build-time dependency trees after asset precompilation on Heroku.
#
# The Heroku Ruby buildpack runs assets:clean after assets:precompile, so we
# hook into that. What gets removed — and why the built documentation site
# survives — is defined in lib/heroku_cleanup.rb.
#
# See: https://github.com/heroku/heroku-buildpack-ruby/issues/792
# Pattern used by: Mastodon, Forem, and recommended by Heroku maintainers.

if Rake::Task.task_defined?('assets:clean')
  Rake::Task['assets:clean'].enhance do
    next unless ENV['RAILS_ENV'] == 'production'

    HerokuCleanup.run!(root: Rails.root, logger: Rails.logger)
  end
end
