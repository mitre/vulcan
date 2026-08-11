# frozen_string_literal: true

require 'rails_helper'
require 'rake'

##
# The documentation site has to be produced by the application's own build, or
# an image can ship without it. These examples pin the two things that make
# that true: the build is attached to asset precompilation, and a failing step
# stops the run instead of passing silently.
#
RSpec.describe 'docs:build' do
  before(:all) do
    load_rake_tasks
  end

  after { Rake::Task['docs:build'].reenable }

  it 'is attached to asset precompilation' do
    expect(Rake::Task['assets:precompile'].prerequisites).to include('docs:build')
  end

  describe DocsSite do
    # Records what was run, in order, and lets a named command fail. Stubbing by
    # command rather than by call position means adding or reordering a step
    # cannot silently change which command an error-path example is exercising.
    def stub_build(failing: nil)
      calls = []

      allow(described_class).to receive(:system) do |environment, command, options|
        calls << { environment: environment, command: command, chdir: options[:chdir] }
        command != failing
      end

      calls
    end

    it 'generates the specification, installs, then builds' do
      calls = stub_build

      described_class.build!

      expect(calls.pluck(:command))
        .to eq(['yarn openapi:docs', 'yarn install --frozen-lockfile', 'yarn build'])
    end

    # The site configuration hard-imports the bundled OpenAPI description, which
    # is generated rather than committed. The script that produces it lives at the
    # application root, so running it from the documentation directory would fail
    # on a clean checkout — which is exactly what an image build is.
    it 'generates the specification from the application root' do
      calls = stub_build

      described_class.build!

      generate = calls.find { |call| call[:command] == 'yarn openapi:docs' }
      expect(generate[:chdir]).to eq(Rails.root.to_s)
    end

    it 'runs the site build inside the documentation directory' do
      calls = stub_build

      described_class.build!

      site_build = calls.find { |call| call[:command] == 'yarn build' }
      expect(site_build[:chdir]).to eq(Rails.root.join('docs').to_s)
    end

    it 'builds under the in-app target and base path' do
      calls = stub_build

      described_class.build!

      expect(calls).to all(
        include(environment: { 'VULCAN_DOCS_TARGET' => 'app', 'VULCAN_DOCS_BASE' => '/docs/' })
      )
    end

    it 'honors an explicit base path over the default' do
      calls = stub_build

      described_class.build!(base: '/guides/')

      expect(calls).to all(
        include(environment: { 'VULCAN_DOCS_TARGET' => 'app', 'VULCAN_DOCS_BASE' => '/guides/' })
      )
    end

    # Each step is named explicitly, so these say which failure they describe
    # rather than depending on how many commands happen to run before it.
    it 'raises when the specification cannot be generated' do
      stub_build(failing: 'yarn openapi:docs')

      expect { described_class.build! }
        .to raise_error(DocsSite::BuildError, /yarn openapi:docs/)
    end

    it 'raises when the dependency install exits non-zero' do
      stub_build(failing: 'yarn install --frozen-lockfile')

      expect { described_class.build! }
        .to raise_error(DocsSite::BuildError, /yarn install/)
    end

    it 'raises when the site build exits non-zero rather than continuing' do
      stub_build(failing: 'yarn build')

      expect { described_class.build! }
        .to raise_error(DocsSite::BuildError, /yarn build/)
    end

    it 'stops at the first failing step instead of running the rest' do
      calls = stub_build(failing: 'yarn openapi:docs')

      expect { described_class.build! }.to raise_error(DocsSite::BuildError)
      expect(calls.pluck(:command)).to eq(['yarn openapi:docs'])
    end

    # Pins the relationship the image prune and the serving controller both
    # rely on — the build output lives INSIDE the documentation tree — without
    # restating the implementation's exact path expression, which an earlier
    # version of this example did (it could not fail for any value the
    # implementation produced). The exact serving coupling is exercised for
    # real by spec/requests/docs_spec.rb, which reads files from this location.
    it 'keeps the build output inside the documentation tree' do
      expect(described_class.output_directory.to_s)
        .to start_with("#{described_class.build_directory}/")
    end
  end

  # The built output itself, not the build mechanics — guarded like the
  # serving specs, so an absent build fails loudly instead of skipping.
  describe 'built output' do
    before(:all) { DocsSiteHelpers.require_built_site! }

    # Frontmatter moustaches never interpolate, so a literal one baked into a
    # <title> puts template syntax in the browser tab of every generated API
    # page. Dynamic-route titles travel through the build's page-data hook.
    it 'interpolates dynamic page titles instead of baking template syntax' do
      titles = Dir[DocsSite.output_directory.join('api/**/*.html').to_s]
               .map { |file| File.read(file)[%r{<title>[^<]*</title>}] }

      expect(titles.length).to be > 100
      expect(titles.grep(/\{\{/)).to eq([])

      # Absence of template syntax is not enough — losing the page-data hook
      # falls every title back to the generic site title with no moustache in
      # sight, so one known page pins the interpolated value itself.
      projects_title = File.read(DocsSite.output_directory.join('api/tags/Projects.html'))[%r{<title>[^<]*</title>}]
      expect(projects_title).to eq('<title>Projects - Vulcan API | Vulcan</title>')
    end
  end
end
