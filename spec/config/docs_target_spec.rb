# frozen_string_literal: true

require 'rails_helper'
require 'json'
require 'open3'

##
# One table decides everything that differs between documentation builds, so a
# mistake in it is silent and reaches the published site. These examples read
# the real module the build reads, under each target, and assert what comes
# back — they do not restate the table.
#
# The module has no dependencies, so importing it costs a bare node process.
#
RSpec.describe 'Documentation build targets' do
  def resolve(target)
    script = <<~NODE
      const { resolveTarget } = await import('./.vitepress/target.mjs');
      console.log(JSON.stringify(resolveTarget(#{target.nil? ? 'undefined' : target.to_json})));
    NODE

    stdout, stderr, status = Open3.capture3(
      { 'VULCAN_DOCS_TARGET' => nil, 'VULCAN_DOCS_BASE' => nil },
      'node', '--input-type=module', '-e', script,
      chdir: Rails.root.join('docs').to_s
    )

    raise "resolving target #{target.inspect} failed: #{stderr}" unless status.success?

    JSON.parse(stdout)
  end

  it 'serves the published site from the domain root' do
    expect(resolve('pages')['base']).to eq('/')
  end

  it 'serves a local preview from its subpath' do
    expect(resolve('local')['base']).to eq('/vulcan/')
  end

  it 'defaults to the local preview when nothing selects a target' do
    expect(resolve(nil)['base']).to eq('/vulcan/')
  end

  it 'mounts the in-app build where the application serves it' do
    expect(resolve('app')['base']).to eq(DocsSite::DEFAULT_BASE)
  end

  it 'treats the API as same-origin only for the in-app build' do
    expect(resolve('app')['api']['sameOrigin']).to be(true)
    expect(resolve('pages')['api']['sameOrigin']).to be(false)
  end

  it 'offers a custom server on the published site and refuses one in-app' do
    expect(resolve('pages')['api']['allowCustomServer']).to be(true)
    expect(resolve('app')['api']['allowCustomServer']).to be(false)
  end

  it 'prefills a placeholder token only where no session can authenticate' do
    expect(resolve('pages')['api']['prefillToken']).to be_present
    expect(resolve('app')['api']['prefillToken']).to be_nil
  end

  it 'marks only the in-app build as in-app' do
    expect(resolve('app')['inApp']).to be(true)
    expect(resolve('pages')['inApp']).to be(false)
    expect(resolve('local')['inApp']).to be(false)
  end

  it 'refuses a target it does not define rather than guessing one' do
    expect { resolve('staging') }.to raise_error(/Unknown documentation target/)
  end

  # The published site is built by CI, and nothing else connects that workflow
  # to the target table: drop or rename the variable there and the site would
  # publish under the local preview's base with every other test green.
  it 'has the deploy workflow select the published-site target' do
    workflow = Rails.root.join('.github/workflows/docs.yml').read

    expect(workflow).to match(/VULCAN_DOCS_TARGET:\s*"pages"/)
  end
end
