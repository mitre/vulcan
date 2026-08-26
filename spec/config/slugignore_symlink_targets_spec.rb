# frozen_string_literal: true

require 'rails_helper'
require 'pathname'

##
# Guards a whole class of Heroku docs-build failures.
#
# The served documentation site symlinks several repo-root files into docs/site
# (e.g. docs/site/getting-started/environment-variables.md ->
# ../../../ENVIRONMENT_VARIABLES.md) and builds them during `assets:precompile`.
# `.slugignore` runs BEFORE that on Heroku, so if a symlink's TARGET is listed
# there the slug compiler deletes it, leaving a DANGLING symlink that VitePress
# drops from the page set — silently 404ing the page, and failing the build
# outright if any page links to it. That is exactly what broke the Heroku docs
# build once already.
#
# This is a correspondence invariant, not a hardcoded list: it scans the real
# tree so a newly added symlink is covered automatically, and fails if any
# docs/site symlink target could be removed by .slugignore.
RSpec.describe '.slugignore vs docs-site symlink targets' do
  # (repo-relative link, repo-relative target) for every symlink under docs/site.
  def self.docs_site_symlinks
    root = Rails.root.join('docs/site')
    Dir.glob(root.join('**/*')).select { |path| File.symlink?(path) }.map do |link|
      target = File.expand_path(File.readlink(link), File.dirname(link))
      [
        Pathname.new(link).relative_path_from(Rails.root).to_s,
        Pathname.new(target).relative_path_from(Rails.root).to_s
      ]
    end
  end

  # Non-comment, non-blank .slugignore patterns.
  def slugignore_patterns
    file = Rails.root.join('.slugignore')
    return [] unless File.exist?(file)

    File.readlines(file).map(&:strip).reject { |line| line.empty? || line.start_with?('#') }
  end

  # Conservative over-approximation of Heroku's .slugignore matching: flag if the
  # target matches by full repo-relative path, by basename, or at any depth. A
  # false positive is a deliberate remove-from-.slugignore conversation; a false
  # negative ships a broken docs build — so the bias is toward flagging.
  def slugignored?(patterns, rel_target)
    base = File.basename(rel_target)
    patterns.any? do |pattern|
      glob = pattern.delete_prefix('/') # a leading slash anchors to the repo root
      File.fnmatch?(glob, rel_target, File::FNM_PATHNAME) ||
        File.fnmatch?(glob, base) ||
        File.fnmatch?("**/#{glob}", rel_target, File::FNM_PATHNAME)
    end
  end

  it 'finds the docs-site symlinks it guards (never passes vacuously)' do
    expect(self.class.docs_site_symlinks).not_to be_empty
  end

  docs_site_symlinks.each do |rel_link, rel_target|
    it "keeps #{rel_target} (symlinked by #{rel_link}) out of .slugignore" do
      expect(slugignored?(slugignore_patterns, rel_target)).to(
        be(false),
        "#{rel_link} symlinks to #{rel_target}, but .slugignore would delete that " \
        'target before the docs build runs — orphaning the symlink and breaking the ' \
        'served page. Remove the target from .slugignore (it is needed at build time).'
      )
    end
  end
end
