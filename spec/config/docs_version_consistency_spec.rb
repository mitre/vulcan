# frozen_string_literal: true

require 'rails_helper'

##
# Hard block against the docs site silently lagging a release.
#
# release_infrastructure_spec already enforces VERSION == package.json ==
# Vulcan::VERSION, but the docs-site "latest release" surfaces were never
# covered: v2.4.1 shipped while the docs still advertised v2.3.7, because the
# version bump swept the code but not docs/site — and even the first docs fix
# missed the VitePress nav dropdown in config.mjs. This spec asserts EVERY
# "current release" surface in the docs matches the code version, so a bump
# that misses any one of them fails the suite (and therefore CI).
#
# The version is read from Vulcan::VERSION (the single source of truth), never
# hardcoded, so this guard needs no edit at each release.
RSpec.describe 'docs/site version consistency' do
  def site_root
    Rails.root.join('docs/site')
  end

  # The version advertised in the landing page's "Current Version" info block.
  def landing_current_version
    block = site_root.join('index.md').read[/:::\s*info\s+Current Version.*?:::/m]
    block && block[/\*\*v(\d+\.\d+\.\d+)\*\*/, 1]
  end

  # The version listed under the release-notes index "Current Release" heading
  # (bounded to that section so "Previous Releases" entries are ignored).
  def release_notes_current_version
    section = site_root.join('release-notes/index.md').read[/^##\s*Current Release\b.*?(?=^##\s|\z)/m]
    section && section[/\*\*\[v(\d+\.\d+\.\d+)\]/, 1]
  end

  # The version presented as current in the VitePress nav's release-notes
  # dropdown: [label, current "Release Notes" link target]. Nil if the dropdown
  # can't be located (its structure changed — the guard should then be updated).
  def nav_current_versions
    config = Rails.root.join('docs/.vitepress/config.mjs').read
    match = config.match(
      %r{text:\s*["']v(\d+\.\d+\.\d+)["'],\s*items:\s*\[\s*\{\s*text:\s*["']Release Notes["'],\s*link:\s*["']/release-notes/v(\d+\.\d+\.\d+)["']}m
    )
    match && [match[1], match[2]]
  end

  it 'landing page advertises the current code version as the latest release' do
    expect(landing_current_version).to eq(Vulcan::VERSION),
                                       "docs/site/index.md 'Current Version' is " \
                                       "#{landing_current_version.inspect}, but Vulcan::VERSION is " \
                                       "#{Vulcan::VERSION.inspect} — update the docs to match the release."
  end

  it 'release-notes index lists the current code version as the current release' do
    expect(release_notes_current_version).to eq(Vulcan::VERSION),
                                             "docs/site/release-notes/index.md 'Current Release' is " \
                                             "#{release_notes_current_version.inspect}, but Vulcan::VERSION is " \
                                             "#{Vulcan::VERSION.inspect} — update the docs to match the release."
  end

  it 'release-notes nav dropdown in config.mjs points at the current version' do
    versions = nav_current_versions
    expect(versions).not_to(be_nil,
                            'could not locate the release-notes version dropdown in ' \
                            'docs/.vitepress/config.mjs — the nav structure changed; update this guard.')
    expect(versions).to all(eq(Vulcan::VERSION)),
                        "the config.mjs release-notes nav (label + current 'Release Notes' link) is " \
                        "#{versions.inspect}, but Vulcan::VERSION is #{Vulcan::VERSION.inspect} — " \
                        'update the nav dropdown label and its Release Notes link to match the release.'
  end

  it 'ships a release-notes page for the current version' do
    page = site_root.join("release-notes/v#{Vulcan::VERSION}.md")
    expect(page).to exist,
                    "missing #{page.relative_path_from(Rails.root)} — a version bump must ship its " \
                    'release-notes page, not just move the latest-release pointer.'
  end
end
