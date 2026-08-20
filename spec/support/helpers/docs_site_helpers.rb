# frozen_string_literal: true

# The docs serving specs read real files from the built documentation site.
# On a machine without one they would otherwise ERROR on a nil glob or assert
# against a 404, which reads as a product bug and hides the real cause. This
# fails once, loudly, with the remedy — and deliberately does NOT skip:
# skipping would silently drop the coverage in exactly the environment (a
# fresh CI runner) where it matters most. CI builds the site in its own
# cached step before the suite runs.
module DocsSiteHelpers
  def self.require_built_site!
    return if DocsSite.output_directory.join('index.html').exist?

    raise 'documentation site not built — run `bundle exec rails docs:build` ' \
          '(CI builds it in a dedicated step before the suite)'
  end
end
