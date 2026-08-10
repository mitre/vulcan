# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'
require 'open3'

##
# The production image is built by pruning the application tree after asset
# precompilation. Anything the application reads from Rails.root while serving
# a request has to survive that prune, or the shipped image returns 404s for
# content that works fine in development.
#
# These examples run the Dockerfile's own prune against a scratch tree rather
# than matching Dockerfile text, so they fail when the prune's behaviour is
# wrong however the command happens to be spelled.
#
RSpec.describe 'Production image prune' do
  # Directories the running application reads from Rails.root, derived from the
  # code that reads them so this guard follows the code if a path moves. The
  # documentation site is built during asset precompilation and then served from
  # disk, so it is a runtime read exactly like the markdown the guide renders.
  let(:runtime_read_paths) do
    [DisaGuideController::GUIDE_DIR, DocsSite.output_directory]
      .map { |path| path.relative_path_from(Rails.root).to_s }
  end

  # Build-only trees that must still be removed. Narrowing the prune is the goal;
  # removing it is not. Note what is NOT listed here: docs/.vitepress as a whole,
  # because its dist subdirectory is the built site. Listing the parent would make
  # this guard demand the deletion of the very thing the image needs.
  let(:build_only_paths) do
    ['docs/node_modules', 'docs/.vitepress/cache', 'docs/plans', 'docs/user-guide', 'node_modules']
  end

  let(:prune_command) { repo_relative_prune(build_cleanup_run_block) }

  it 'keeps the content the application serves at runtime' do
    in_pruned_scratch_tree do |dir|
      runtime_read_paths.each do |path|
        expect(File.read(File.join(dir, path, 'content.md'))).to eq("guide content\n")
        expect(File.read(File.join(dir, path, 'attachments', 'sample.pdf'))).to eq('pdf')
      end
    end
  end

  it 'still removes the build-only trees' do
    in_pruned_scratch_tree do |dir|
      build_only_paths.each do |path|
        expect(Dir.exist?(File.join(dir, path))).to be(false)
      end
    end
  end

  def in_pruned_scratch_tree
    Dir.mktmpdir('vulcan-image-prune') do |dir|
      seed_scratch_tree(dir)

      # Mirrors the Dockerfile's own `set -eu`, so a prune command that errors
      # here fails this example instead of being masked by a later one
      # succeeding — the commands are sequenced with `;`, not `&&`.
      _stdout, stderr, status = Open3.capture3('bash', '-c', "set -eu; #{prune_command}", chdir: dir)
      raise "production image prune failed: #{stderr}" unless status.success?

      yield dir
    end
  end

  def seed_scratch_tree(dir)
    runtime_read_paths.each do |path|
      FileUtils.mkdir_p(File.join(dir, path, 'attachments'))
      File.write(File.join(dir, path, 'content.md'), "guide content\n")
      File.write(File.join(dir, path, 'attachments', 'sample.pdf'), 'pdf')
    end

    build_only_paths.each do |path|
      FileUtils.mkdir_p(File.join(dir, path))
      File.write(File.join(dir, path, 'placeholder'), 'x')
    end
  end

  # The repo-relative portion of the build stage's cleanup. Commands later in
  # the same instruction touch absolute paths that only exist inside the image.
  def repo_relative_prune(block)
    absolute_marker = ['find "${BUNDLE_PATH}"', 'find /rails'].filter_map { |marker| block.index(marker) }.min
    segment = absolute_marker ? block[0, absolute_marker] : block
    start = segment.index('rm -rf')

    raise 'Dockerfile cleanup no longer starts with an rm -rf prune — update this guard' if start.nil?

    segment[start..].strip.sub(/&&\s*\z/, '')
  end

  # The RUN instruction that prunes the tree after precompiling assets, with its
  # line continuations joined into one shell command.
  def build_cleanup_run_block
    lines = Rails.root.join('Dockerfile').read.lines.map(&:chomp)

    lines.each_index do |index|
      next unless lines[index].start_with?('RUN ')

      block = join_continuations(lines, index)
      return block if block.include?('assets:precompile')
    end

    raise 'No asset-precompiling RUN instruction found in the Dockerfile'
  end

  def join_continuations(lines, index)
    collected = []

    loop do
      line = lines[index]
      collected << line.delete_suffix('\\')
      break unless line.end_with?('\\')

      index += 1
    end

    collected.join(' ')
  end
end
