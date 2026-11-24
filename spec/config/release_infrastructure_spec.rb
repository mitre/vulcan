# frozen_string_literal: true

require 'rails_helper'

##
# Guards on the release pipeline's *shape*, and on the release documentation
# telling the truth about it.
#
# This spec used to assert only that `release.yml` triggers on
# `release: published`. That passed happily while:
#
#   * every real release publish took a QEMU path that cannot finish, because
#     the Build Cloud driver was gated on `github.event.inputs`, which is empty
#     on the `release: published` trigger (2.4.0, 2.4.1 and 2.4.2 all timed
#     out; DockerHub never received a 2.4.0 or 2.4.2 image at all);
#   * nothing checked that a release was built from tested code;
#   * docs/site/development/release-process.md described a tag-triggered,
#     git-cliff-driven, test-gated process that does not exist in any workflow.
#
# A guard that passes against a pipeline this broken is not a guard. The
# examples below assert requirements, and each one would have failed against
# the pipeline as it shipped 2.4.2.
RSpec.describe 'release infrastructure' do
  # Releases are published by a human in the GitHub Releases UI, which fires
  # `release: published`. No workflow is tag-triggered. See
  # docs/site/development/release-process.md.

  def workflow(name)
    Rails.root.join('.github/workflows', name).read
  end

  def workflow_yaml(name)
    YAML.safe_load_file(Rails.root.join('.github/workflows', name), aliases: true)
  end

  # Workflow source with comment-only lines removed. These guards are about
  # what the workflow *evaluates*, not about prose; the comments explain the
  # very mistakes being guarded against and would otherwise trip them.
  def workflow_expressions(name)
    workflow(name).lines.reject { |line| line.lstrip.start_with?('#') }.join
  end

  # Psych resolves the YAML 1.1 boolean `on`, so a workflow's trigger block
  # lands under the `true` key rather than the string 'on'.
  def workflow_on(name)
    yaml = workflow_yaml(name)
    yaml[true] || yaml['on']
  end

  def trigger_block(parsed)
    parsed[true] || parsed['on']
  end

  # Every workflow that takes part in building or pushing an image.
  def publish_workflows
    %w[release.yml mainline.yml docker-publish.yml]
  end

  # Budgets that have already timed out in production: 20 minutes twice
  # (2.4.0, 2.4.1) and 45 minutes once (2.4.2) - all on the emulated path.
  def failed_budgets
    [20, 45]
  end

  # The slowest Build Cloud release publish on record (v2.3.6, 10m26s). A
  # budget below this would start failing good builds.
  def slowest_measured_publish_minutes
    11
  end

  def release_doc
    Rails.root.join('docs/site/development/release-process.md').read
  end

  describe 'image publish trigger' do
    it 'release.yml publishes on published GitHub releases' do
      expect(workflow_on('release.yml')['release']['types']).to include('published'),
                                                                'release.yml must publish the image when a GitHub Release is published'
    end

    it 'keeps a workflow_dispatch recovery path for re-publishing a tag' do
      expect(workflow_on('release.yml')).to have_key('workflow_dispatch'),
                                            'a failed publish must be re-runnable without cutting a new release; 2.4.1 was ' \
                                            'only ever published because someone re-dispatched the workflow by hand'
    end

    # The documented trigger and the implemented trigger drifted apart, and the
    # docs won: people pushed tags and nothing happened. Assert they agree in
    # BOTH directions, so this guard stays correct if the trigger ever changes.
    it 'no workflow is tag-triggered, and the docs do not claim otherwise' do
      tag_triggered = Rails.root.glob('.github/workflows/*.yml').select do |path|
        on = trigger_block(YAML.safe_load_file(path, aliases: true))
        on.is_a?(Hash) && on['push'].is_a?(Hash) && on['push'].key?('tags')
      end

      if tag_triggered.empty?
        expect(release_doc).not_to match(/\breleases are tag-triggered\b/i),
                                   'release-process.md calls releases tag-triggered, but no workflow has a ' \
                                   '`push: tags:` trigger — pushing a tag fires nothing. Either add the ' \
                                   'trigger or fix the prose.'
      else
        expect(release_doc).to match(/tag/i),
                               "#{tag_triggered.join(', ')} is tag-triggered but release-process.md " \
                               'never mentions tags.'
      end
    end
  end

  describe 'multi-architecture build driver' do
    # THE regression guard. 6aa8d462 wrapped the Build Cloud buildx setup in
    # `if: github.event.inputs.use_build_cloud == 'true'`. That context is
    # populated only for workflow_dispatch, so on `release: published` and
    # `push:` the condition was false and an emulated build ran instead —
    # 19m33s and still unfinished, against 2m35s on Build Cloud.
    it 'never gates publish infrastructure on github.event.inputs' do
      publish_workflows.each do |name|
        expect(workflow_expressions(name)).not_to include('github.event.inputs'),
                                                  "#{name} references github.event.inputs, which is empty on the " \
                                                  'release: published and push: triggers these workflows actually run ' \
                                                  'on. Gating a build driver (or anything else) on it silently selects ' \
                                                  'the other branch for every real publish.'
      end
    end

    it 'selects the build driver unconditionally' do
      steps = workflow_yaml('docker-publish.yml')['jobs']['publish']['steps']
      buildx = steps.select { |s| s['uses'].to_s.include?('docker/setup-buildx-action') }

      expect(buildx.size).to eq(1),
                             'there must be exactly one buildx setup step. More than one means the driver ' \
                             'is being chosen at runtime, which is how the release build regressed.'
      expect(buildx.first).not_to have_key('if'),
                                  'the buildx setup step must not be conditional — a conditionally-skipped ' \
                                  'builder silently falls through to a path that cannot complete.'
      expect(buildx.first.dig('with', 'driver')).to eq('cloud'),
                                                    'the publish must use the Docker Build Cloud driver; ' \
                                                    'emulated multi-arch builds of this image do not finish'
    end

    it 'does not set up QEMU emulation on the publish path' do
      publish_workflows.each do |name|
        expect(workflow_expressions(name)).not_to include('setup-qemu-action'),
                                                  "#{name} sets up QEMU. Emulating arm64 while compiling Ruby and " \
                                                  'jemalloc from source on a shared 4-vCPU runner is the measured cause ' \
                                                  'of three consecutive release timeouts.'
      end
    end
  end

  describe 'publish job budget' do
    # The budget must sit between the slowest build that has actually
    # succeeded and the budget that was already raised once and still failed.
    # Both bounds matter: too low fails good builds, too high means a wedged
    # build burns most of an hour before anyone is told.
    it 'bounds the publish timeout by measurement, not by optimism' do
      default = workflow_on('docker-publish.yml')['workflow_call']['inputs']
                .dig('timeout_minutes', 'default')

      expect(default).to be_a(Integer)
      aggregate_failures do
        expect(default).to be < failed_budgets.max,
                           "the publish budget is #{default} minutes, but #{failed_budgets.max} was " \
                           'already tried and still timed out. A budget is not a fix; ground it in a ' \
                           'measured successful build.'
        expect(default).to be >= slowest_measured_publish_minutes,
                           "the publish budget is #{default} minutes, below the slowest publish that has " \
                           "actually succeeded (#{slowest_measured_publish_minutes}) - it would cancel " \
                           'good builds.'
      end
    end

    it 'gives every publish job a timeout' do
      publish_workflows.each do |name|
        workflow_yaml(name)['jobs'].each do |job_name, job|
          next if job.key?('uses') # reusable-workflow callers inherit the callee's budget

          expect(job).to have_key('timeout-minutes'),
                         "#{name} job '#{job_name}' has no timeout-minutes and would run to GitHub's " \
                         '6-hour default'
        end
      end
    end
  end

  describe 'release gating' do
    # Nothing used to check this. A release could be published from any ref,
    # with any VERSION, with red CI, and the image would ship to DockerHub and
    # on to Iron Bank.
    it 'gates the image publish on a verification job' do
      jobs = workflow_yaml('release.yml')['jobs']
      publish = jobs.values.find { |j| j['uses'].to_s.include?('docker-publish.yml') }

      expect(publish).not_to be_nil, 'release.yml must delegate to the shared docker-publish workflow'
      expect(publish['needs']).to be_present,
                                  'the release publish must depend on a verification job; otherwise a ' \
                                  'release published from a red or mistagged commit ships to DockerHub ' \
                                  'and to Iron Bank unchecked'

      gate = jobs[Array(publish['needs']).first]
      script = gate['steps'].map { |s| s['run'].to_s }.join("\n")

      aggregate_failures do
        expect(script).to include('VERSION'),
                          'the gate must assert VERSION at the tagged commit matches the tag, or the ' \
                          'image ships under a tag that disagrees with Vulcan::VERSION inside it'
        expect(script).to match(/merge-base|is-ancestor/),
                          'the gate must assert the tagged commit is on master'
        expect(script).to include('workflows/ci.yml/runs'),
                          "the gate must assert ci.yml concluded success for the tagged commit's SHA"
      end
    end
  end

  describe 'publish path is not duplicated' do
    # release.yml and mainline.yml were line-for-line copies of the same build
    # and push steps. The driver regression existed in both, and mainline's
    # copy kept limping along so nobody noticed release had stopped publishing.
    it 'has exactly one implementation of the build-and-push steps' do
      implementors = publish_workflows.select do |name|
        workflow_expressions(name).include?('docker/bake-action')
      end

      expect(implementors).to eq(['docker-publish.yml']),
                              'the bake invocation must live only in the shared docker-publish workflow; ' \
                              "found it in #{implementors.join(', ')}"
    end

    # A re-publish dispatched from the default branch must still build the
    # tag's tree. If the shared workflow checked out its own `github.ref`, it
    # would build master and push it under the release's version number.
    it 'makes every caller state the ref to build' do
      expect(workflow_on('docker-publish.yml')['workflow_call']['inputs'])
        .to include('ref'), 'docker-publish.yml must take the ref to build as a required input'

      checkout = workflow_yaml('docker-publish.yml')['jobs']['publish']['steps']
                 .find { |s| s['uses'].to_s.include?('actions/checkout') }
      expect(checkout.dig('with', 'ref')).to eq('${{ inputs.ref }}'),
                                             'the publish checkout must use the caller-supplied ref'

      %w[release.yml mainline.yml].each do |name|
        refs = workflow_yaml(name)['jobs'].values
                                          .select { |j| j['uses'].to_s.include?('docker-publish.yml') }
                                          .map { |j| j.dig('with', 'ref') }
        expect(refs).to all(be_present), "#{name} must tell docker-publish.yml which ref to build"
        expect(refs).to all(satisfy { |r| r.exclude?('github.ref') }),
                        "#{name} passes github.ref, which is the dispatched ref rather than the ref " \
                        'being released'
      end
    end

    it 'routes both the release and mainline publishes through the shared workflow' do
      %w[release.yml mainline.yml].each do |name|
        callers = workflow_yaml(name)['jobs'].values.select do |job|
          job['uses'].to_s.include?('docker-publish.yml')
        end
        expect(callers).not_to be_empty, "#{name} must call .github/workflows/docker-publish.yml"
      end
    end
  end

  describe 'release-process.md matches the automation' do
    it 'does not credit automation with changelog generation that no workflow runs' do
      cliff_users = Rails.root.glob('.github/workflows/*.yml').select do |path|
        File.read(path).match?(/git-cliff|git_cliff|cliff\.toml/)
      end

      next unless cliff_users.empty?

      expect(release_doc).not_to match(/git-cliff (?:generates|commits|runs)|runs git-cliff/i),
                                 'release-process.md says git-cliff generates or commits the changelog, ' \
                                 'but no workflow invokes it. CHANGELOG.md and the release-notes page are ' \
                                 'hand-authored; the doc must say so.'
    end

    it 'does not claim the release image is gated on a full test-suite run' do
      expect(release_doc).not_to match(/if (?:all )?(?:jobs|tests) pass.*docker|if tests fail, docker is skipped/i),
                                 'release-process.md describes ci.yml running the suite and then gating ' \
                                 'the image. ci.yml triggers only on push to master and pull_request; it ' \
                                 'has no release trigger and no docker job.'
    end

    # release.yml strips the `v` (`version=${raw#v}`), so mitre/vulcan:v2.4.2
    # has never existed. Telling readers to pull it is half the reason the
    # missing 2.4.2 image went unnoticed.
    it 'never tells the reader to pull a v-prefixed image tag' do
      # Prose that warns the v-prefixed tag does not exist is wanted. What must
      # never happen is a *runnable* instruction using one, which is what
      # `docker pull mitre/vulcan:v2.3.2` in a copy-paste block was.
      in_fence = false
      offenders = release_doc.lines.filter_map do |line|
        if line.start_with?('```')
          in_fence = !in_fence
          next
        end
        line.strip if in_fence && line.match?(%r{mitre/vulcan:v\d+\.\d+\.\d+})
      end

      aggregate_failures do
        expect(offenders).to be_empty,
                             "release-process.md has #{offenders.join(' / ')} in a copy-paste block, but " \
                             'release.yml strips the prefix, so the image tag is the bare semver ' \
                             '(mitre/vulcan:2.4.2)'
        expect(release_doc).not_to match(%r{(?:push|publish)(?:e[sd])?\s+\S{0,2}mitre/vulcan:v\d}i),
                                   'release-process.md claims a v-prefixed image tag is pushed. None ever ' \
                                   'has been; release.yml strips the prefix.'
      end
    end

    it 'names every workflow that participates in a release' do
      aggregate_failures do
        (publish_workflows + ['ci.yml']).each do |name|
          expect(release_doc).to include(name),
                                 "release-process.md does not mention #{name}, which a releaser needs to " \
                                 'know about'
        end
      end
    end

    # Someone following the doc verbatim must not end up with red CI. Every
    # file docs_version_consistency_spec and the version guards enforce has to
    # appear in the doc as something the releaser edits.
    it 'lists every version surface the suite enforces' do
      surfaces = [
        'VERSION',
        'package.json',
        'docs/site/index.md',
        'docs/site/release-notes/index.md',
        'docs/.vitepress/config.mjs',
        'docs/site/release-notes/v',
        'CHANGELOG.md'
      ]

      aggregate_failures do
        surfaces.each do |surface|
          expect(release_doc).to include(surface),
                                 "release-process.md never mentions #{surface}, so a releaser following " \
                                 'it would miss a surface that docs_version_consistency_spec or ' \
                                 'release_infrastructure_spec fails on'
        end
      end
    end

    it 'tells the releaser to confirm the image reached DockerHub' do
      expect(release_doc).to match(/hub\.docker\.com|docker manifest inspect|DockerHub/i),
                             'the 2.4.2 release shipped with no image on DockerHub and nobody noticed. ' \
                             'The verification steps must include checking the registry.'
    end

    it 'documents the Iron Bank merge request step' do
      expect(release_doc).to match(/iron bank|repo1/i),
                             'half of what release.yml does is open a merge request against repo1; the ' \
                             'release doc must cover it and how to confirm it landed'
    end
  end

  describe 'changelog configuration' do
    # cliff.toml is kept as a local drafting aid (`git cliff --unreleased`),
    # not as automation. Nothing in CI runs it; see the doc guard above.
    it 'cliff.toml exists with Keep a Changelog sections' do
      config_path = Rails.root.join('cliff.toml')
      expect(config_path).to exist
      content = config_path.read
      expect(content).to include('Added')
      expect(content).to include('Fixed')
      expect(content).to include('Keep a Changelog')
    end

    it 'CHANGELOG.md has an entry for the current version' do
      changelog = Rails.root.join('CHANGELOG.md').read
      expect(changelog).to match(/^## \[v?#{Regexp.escape(Vulcan::VERSION)}\]/o),
                           "CHANGELOG.md has no '## [v#{Vulcan::VERSION}]' section. A version bump must " \
                           'ship its changelog entry.'
    end
  end

  describe 'version consistency' do
    it 'VERSION file, package.json, and Vulcan::VERSION all match' do
      version_file = Rails.root.join('VERSION').read.strip.delete_prefix('v')
      package_json = JSON.parse(Rails.root.join('package.json').read)['version']

      expect(version_file).to eq(Vulcan::VERSION), 'VERSION file mismatch'
      expect(package_json).to eq(Vulcan::VERSION), 'package.json mismatch'
    end
  end

  describe 'API version controller' do
    it 'Api::VersionController exists and skips authentication' do
      expect(defined?(Api::VersionController)).to eq('constant')
      callbacks = Api::VersionController._process_action_callbacks
                                        .select { |cb| cb.kind == :before }
                                        .map(&:filter)
      expect(callbacks).not_to include(:authenticate_user!)
    end
  end
end
