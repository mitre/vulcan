# frozen_string_literal: true

require 'rails_helper'
require 'rake'

##
# The documentation site builds during asset precompilation, which installs a
# second dependency tree under docs/. On Heroku nothing else removes either
# tree from the slug — the ignore file has already had its say before the
# buildpack runs — so the cleanup owns both. The built site itself is served
# by the application at runtime and must survive the sweep.
#
RSpec.describe HerokuCleanup do
  describe '.targets' do
    let(:root) { Pathname.new('/app') }

    it 'lists both dependency trees and the docs build cache' do
      expect(described_class.targets(root)).to eq([
                                                    Pathname.new('/app/node_modules'),
                                                    Pathname.new('/app/docs/node_modules'),
                                                    Pathname.new('/app/docs/.vitepress/cache')
                                                  ])
    end

    it 'does not target the built documentation site, which the app serves at runtime' do
      expect(described_class.targets(root)).not_to include(Pathname.new('/app/docs/.vitepress/dist'))
    end
  end

  describe '.run!' do
    it 'removes every existing target and preserves the built site' do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        FileUtils.mkdir_p(root.join('node_modules/some-package'))
        FileUtils.mkdir_p(root.join('docs/node_modules/some-package'))
        FileUtils.mkdir_p(root.join('docs/.vitepress/cache'))
        FileUtils.mkdir_p(root.join('docs/.vitepress/dist/assets'))
        File.write(root.join('docs/.vitepress/dist/index.html'), '<html></html>')

        described_class.run!(root: root, logger: Logger.new(File::NULL))

        expect(root.join('node_modules')).not_to exist
        expect(root.join('docs/node_modules')).not_to exist
        expect(root.join('docs/.vitepress/cache')).not_to exist
        expect(root.join('docs/.vitepress/dist/index.html').read).to eq('<html></html>')
      end
    end

    it 'skips targets that are already absent' do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        expect { described_class.run!(root: root, logger: Logger.new(File::NULL)) }.not_to raise_error
      end
    end
  end

  describe 'rake wiring' do
    before(:all) { load_rake_tasks }

    # The task's other actions belong to Propshaft and touch public/assets, so
    # the enhancement is exercised directly — located by its source file, which
    # also asserts it is genuinely attached to assets:clean.
    def cleanup_action
      Rake::Task['assets:clean'].actions.find do |action|
        action.source_location.first.end_with?('lib/tasks/heroku_cleanup.rake')
      end
    end

    it 'attaches the cleanup to assets:clean' do
      expect(cleanup_action).not_to be_nil
    end

    it 'runs the cleanup in production' do
      expect(described_class).to receive(:run!).with(root: Rails.root, logger: anything)

      ClimateControl.modify(RAILS_ENV: 'production') do
        cleanup_action.call(Rake::Task['assets:clean'])
      end
    end

    it 'does not run outside production' do
      expect(described_class).not_to receive(:run!)

      ClimateControl.modify(RAILS_ENV: 'test') do
        cleanup_action.call(Rake::Task['assets:clean'])
      end
    end
  end
end
