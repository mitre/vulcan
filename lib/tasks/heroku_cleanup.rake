# frozen_string_literal: true

# Remove node_modules after asset precompilation on Heroku.
#
# esbuild compiles JavaScript into app/assets/builds/ during assets:precompile.
# After that, node_modules is dead weight in the slug (~150-300 MB).
#
# The Heroku Ruby buildpack runs assets:clean after assets:precompile,
# so we hook into that to remove node_modules automatically.
#
# See: https://github.com/heroku/heroku-buildpack-ruby/issues/792
# Pattern used by: Mastodon, Forem, and recommended by Heroku maintainers.

if Rake::Task.task_defined?('assets:clean')
  Rake::Task['assets:clean'].enhance do
    next unless ENV['RAILS_ENV'] == 'production'

    node_modules = Rails.root.join('node_modules')
    if node_modules.exist?
      Rails.logger.info "Heroku cleanup: removing node_modules (#{`du -sh #{node_modules}`.strip})"
      FileUtils.remove_dir(node_modules, true)
      Rails.logger.info 'Heroku cleanup: node_modules removed'
    end
  end
end
