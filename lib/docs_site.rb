# frozen_string_literal: true

##
# Produces the documentation site that the application serves.
#
# The site is generated rather than committed, so a released image has to build
# its own copy. Asset precompilation is the seam: the image build already runs
# it, so attaching the documentation build there means no separate step has to
# be remembered or wired into the Dockerfile.
#
module DocsSite
  # Where the site is mounted when the application serves it. The route and this
  # value have to agree — the built pages request their assets relative to the
  # base they were compiled under, so a mismatch 404s every one of them.
  DEFAULT_BASE = '/docs/'

  # Selects the in-app entry in the documentation build's target table, which
  # is where everything else that differs between builds is declared.
  TARGET = 'app'

  DIRECTORY = 'docs'

  # The site's configuration hard-imports the bundled OpenAPI description, which
  # is generated rather than committed. On a clean checkout — which is exactly
  # what an image build is — that file does not exist yet and the documentation
  # build dies on the import. This runs from the application root, where the
  # script and the specification sources live.
  SPEC_COMMAND = 'yarn openapi:docs'

  # Dependencies first: the documentation tree has its own manifest, and the
  # application's own install does not reach into it.
  BUILD_COMMANDS = [
    'yarn install --frozen-lockfile',
    'yarn build'
  ].freeze

  class BuildError < StandardError; end

  class << self
    def build!(base: default_base)
      run(SPEC_COMMAND, base, Rails.root)
      BUILD_COMMANDS.each { |command| run(command, base, source_directory) }

      output_directory
    end

    def default_base
      ENV.fetch('VULCAN_DOCS_BASE', DEFAULT_BASE)
    end

    def source_directory
      Rails.root.join(DIRECTORY)
    end

    def output_directory
      source_directory.join('.vitepress/dist')
    end

    private

    # A failed documentation build has to stop the run it is part of. Asset
    # precompilation reporting success over a site that never built is how an
    # image ships without its documentation.
    #
    # The target name selects everything that differs between builds; the mount
    # path is passed alongside it because the route defined here is what makes
    # it true, and the documentation build is only being told.
    def run(command, base, directory)
      environment = { 'VULCAN_DOCS_TARGET' => TARGET, 'VULCAN_DOCS_BASE' => base }

      return if system(environment, command, chdir: directory.to_s)

      raise BuildError, "documentation site build failed: #{command}"
    end
  end
end
