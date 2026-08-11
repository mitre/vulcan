# frozen_string_literal: true

require 'rails_helper'

##
# Publishing is structural: a page exists on the site only if its source lives
# under the curated site root, so a tree outside that root cannot be published
# and there is no exclude list to forget. These examples pin the invariant
# against the BUILT site — both sides derived from the filesystem — so a
# curation regression (a widened source root, a built page with no source
# under the root) fails the suite instead of publishing something nobody
# decided to publish. A tree deliberately moved inside the site root gains
# sources under the root and is therefore published — placement itself is the
# curation decision this layout makes, and no spec can second-guess it.
#
RSpec.describe 'Docs site curation' do
  before(:all) { DocsSiteHelpers.require_built_site! }

  # A built page corresponds to its markdown source, or to a dynamic-route
  # template ([param].md) in the same directory — the API reference generates
  # its operation and tag pages that way.
  def sourced?(relative)
    return true if DocsSite.site_root.join(relative).sub_ext('.md').exist?

    source_dir = DocsSite.site_root.join(relative).dirname
    source_dir.directory? &&
      source_dir.children.any? { |entry| entry.basename.to_s.match?(/\A\[.+\]\.md\z/) }
  end

  # 404.html is emitted by the generator itself with no source page — the one
  # exemption, a property of the tool rather than editorial policy.
  it 'publishes only pages that originate under the site root' do
    orphaned = Dir.glob(DocsSite.output_directory.join('**/*.html'))
                  .map { |page| Pathname.new(page).relative_path_from(DocsSite.output_directory) }
                  .reject { |relative| relative.to_s == '404.html' }
                  .reject { |relative| sourced?(relative) }

    expect(orphaned.map(&:to_s).sort).to eq([])
  end
end
