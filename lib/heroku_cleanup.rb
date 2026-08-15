# frozen_string_literal: true

##
# Removes build-time dependency trees after asset precompilation on Heroku.
#
# Two trees exist by then: the application's node_modules (esbuild inputs,
# compiled into app/assets/builds/) and the documentation site's
# docs/node_modules plus its build cache (the site is built during
# precompilation and installs its own dependencies). Both are dead weight in
# the slug once their outputs exist. The built site at docs/.vitepress/dist
# is NOT a build input — the application serves it at runtime — so it is
# deliberately not a target.
#
# The ignore file cannot handle any of this: .slugignore runs before the
# buildpack, and every one of these trees is created during the build.
module HerokuCleanup
  def self.targets(root)
    [
      root.join('node_modules'),
      root.join('docs/node_modules'),
      root.join('docs/.vitepress/cache')
    ]
  end

  def self.run!(root:, logger:)
    targets(root).each do |target|
      next unless target.exist?

      logger.info "Heroku cleanup: removing #{target} (#{`du -sh #{target}`.split.first})"
      FileUtils.remove_dir(target, true)
    end
    logger.info 'Heroku cleanup: build dependencies removed'
  end
end
