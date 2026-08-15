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

  # A page nobody can navigate to is findable only by search — published in
  # the index yet invisible to anyone reviewing the site. Reachability is
  # derived from the built pages themselves: the navigation and sidebar are
  # server-rendered into every page, so a breadth-first walk of the rendered
  # links from the landing page must visit every built page. No allowlist:
  # a page is linked from the navigation, or it is not published.
  describe 'every built page is reachable from the navigation' do
    # The site builds with a mount base; rendered hrefs carry it. Links are
    # extensionless (cleanUrls), so a path maps to path.html or to the
    # directory index. Resolution is by existence, never by extension
    # sniffing — a dotted segment like a version number (v2.3.7) is a page,
    # while an asset resolves to nothing and is skipped.
    def resolve_built_page(href, base)
      path = href.split('#', 2).first.split('?', 2).first
      return nil unless path&.start_with?(base)

      relative = CGI.unescape(path.delete_prefix(base))
      return 'index.html' if relative.empty?
      return relative if relative.end_with?('.html')

      candidate = "#{relative}.html"
      return candidate if DocsSite.output_directory.join(candidate).exist?

      index = File.join(relative, 'index.html')
      DocsSite.output_directory.join(index).exist? ? index : nil
    end

    it 'walks the rendered links and leaves no page unvisited' do
      base = DocsSite.default_base
      visited = Set.new
      queue = ['index.html']

      until queue.empty?
        page = queue.shift
        next if visited.include?(page)

        visited << page
        html = DocsSite.output_directory.join(page).read
        html.scan(/href="([^"]+)"/) do |(href)|
          target = resolve_built_page(href, base)
          queue << target if target && visited.exclude?(target)
        end
      end

      built = Dir.glob(DocsSite.output_directory.join('**/*.html'))
                 .map { |page| Pathname.new(page).relative_path_from(DocsSite.output_directory).to_s }
                 .reject { |relative| relative == '404.html' }

      expect((built - visited.to_a).sort).to eq([])
    end
  end
end
