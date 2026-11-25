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
  # (2.4.0, 2.4.1) and 45 minutes once (2.4.2) - all on the emulated path,
  # which the mainline runs show needs 62-64 minutes.
  def failed_budgets
    [20, 45]
  end

  # Slowest build observed per driver, rounded up to whole minutes:
  #   cloud     10m26s (v2.3.6 release)
  #   emulated  64m10s (mainline run 43060030274; the other four recent
  #             mainline builds were 62m13s, 62m35s, 63m15s, 63m43s)
  def slowest_measured_minutes
    { 'cloud' => 11, 'emulated' => 65 }
  end

  # The driver every caller must resolve to on its own automatic trigger.
  # Build Cloud minutes are one small monthly pot shared across the whole
  # organisation, so the free path is the default everywhere and the fast path
  # is opt-in.
  def default_builder
    'emulated'
  end

  def callers
    %w[release.yml mainline.yml]
  end

  # The job-level `timeout-minutes` expression, as { builder => minutes }.
  def publish_budgets
    expr = workflow_yaml('docker-publish.yml')['jobs']['publish']['timeout-minutes'].to_s
    cloud, emulated = expr.scan(/\d+/).map(&:to_i)
    { 'cloud' => cloud, 'emulated' => emulated }
  end

  def publish_steps
    workflow_yaml('docker-publish.yml')['jobs']['publish']['steps']
  end

  # What each caller passes for `builder`, per caller workflow.
  def builder_expression(name)
    workflow_yaml(name)['jobs'].values
                               .select { |j| j['uses'].to_s.include?('docker-publish.yml') }
                               .map { |j| j.dig('with', 'builder') }
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

    # Both drivers are legitimate and the choice is a cost decision, so this
    # no longer asserts a single driver. It asserts the property that actually
    # broke: the choice must come from a declared workflow_call input with a
    # default, which is populated on every trigger, and never from event
    # payload fields that are empty on `release: published` and `push:`.
    it 'chooses the driver from a declared input with a default' do
      builder = workflow_on('docker-publish.yml')['workflow_call']['inputs']['builder']

      expect(builder).not_to be_nil, 'docker-publish.yml must take the driver as a workflow_call input'
      expect(builder['default']).to eq(default_builder),
                                    'the driver must default to the free path. Defaulting to Build Cloud ' \
                                    "would spend the organisation's small shared minute pot on any caller " \
                                    'that forgets to pass a driver.'
    end

    # The generalised form of the original bug, and the guard most worth
    # having. `6aa8d462` gated the Build Cloud driver on
    # `github.event.inputs.use_build_cloud`, a field that exists only for
    # workflow_dispatch. On the `release: published` and `push:` triggers the
    # condition was simply false, so the workflow took the other branch with
    # nobody choosing it. Any step condition reading the event payload has the
    # same failure mode, so none are allowed: conditions must read the
    # workflow's own declared inputs, which are populated on every trigger.
    it 'never conditions a publish step on anything outside its declared inputs' do
      conditions = publish_steps.filter_map { |step| [step['name'], step['if']] if step.key?('if') }

      expect(conditions).not_to be_empty

      aggregate_failures do
        conditions.each do |name, condition|
          referenced = condition.to_s.scan(/\b(?:github|env|vars|secrets|inputs)\.[\w.]+/).uniq
          expect(referenced).to all(start_with('inputs.')),
                                "the step '#{name}' is conditioned on #{referenced.join(', ')}. A publish " \
                                "step's condition must read only this workflow's declared inputs; " \
                                'anything from the event payload is empty on the triggers that matter and ' \
                                'silently selects the opposite branch.'
        end
      end
    end

    it 'guards each driver setup step on the builder input alone' do
      driver_steps = publish_steps.select do |step|
        step['uses'].to_s.match?(%r{docker/setup-(buildx|qemu)-action})
      end

      expect(driver_steps).not_to be_empty

      aggregate_failures do
        driver_steps.each do |step|
          condition = step['if'].to_s
          expect(condition).to match(/\Ainputs\.builder == '(?:cloud|emulated)'\z/),
                               "the step '#{step['name']}' is guarded on #{condition.inspect}. Driver " \
                               'setup must be keyed on inputs.builder and nothing else - the release ' \
                               'outage came from keying it on a context that is empty on the real trigger.'
        end
      end
    end

    it 'puts the cloud and emulated drivers on mutually exclusive paths' do
      driver_steps = publish_steps.filter_map do |step|
        next unless step['uses'].to_s.match?(%r{docker/setup-(buildx|qemu)-action})

        [step['if'].to_s[/'(cloud|emulated)'/, 1], step]
      end
      by_builder = driver_steps.group_by(&:first).transform_values { |pairs| pairs.map(&:last) }

      aggregate_failures do
        expect(by_builder.keys).to contain_exactly('cloud', 'emulated'),
                                   'both drivers must be reachable: cloud for releases, emulated as the ' \
                                   'free path for mainline and as the release fallback when the shared ' \
                                   'Build Cloud pot is exhausted'

        cloud_buildx = by_builder['cloud'].select { |s| s['uses'].include?('setup-buildx-action') }
        expect(cloud_buildx.size).to eq(1)
        expect(cloud_buildx.first.dig('with', 'driver')).to eq('cloud'),
                                                            'the cloud path must actually use the cloud driver'

        expect(by_builder['emulated'].map { |s| s['uses'][%r{docker/setup-\w+}] })
          .to include('docker/setup-qemu'),
              'the emulated path must set up QEMU, or an arm64 leg cannot be built at all'
        expect(by_builder['cloud'].pluck('uses').join)
          .not_to include('setup-qemu-action'),
                  'the cloud path must not set up QEMU; Build Cloud builds each architecture natively'
      end
    end
  end

  describe 'driver cost policy' do
    # Build Cloud minutes are a single small monthly pot shared across the
    # whole organisation. The free path is therefore the default on every
    # automatic trigger, and the fast path is something a human asks for.
    it 'defaults every automatic trigger to the free driver' do
      aggregate_failures do
        callers.each do |name|
          exprs = builder_expression(name)
          expect(exprs).not_to be_empty, "#{name} must state which driver it builds on"
          expect(exprs).to all(match(/\|\|\s*'#{default_builder}'\s*\}\}/)),
                           "#{name} resolves the driver as #{exprs.inspect}. The final fallback must be " \
                           "'#{default_builder}', so a trigger that supplies nothing gets the free path " \
                           "rather than spending the organisation's shared Build Cloud minutes."
        end
      end
    end

    # The other half of the original bug: `github.event.inputs` is empty on
    # `release: published`, so before this change there was no way to ask for
    # the fast driver on a real release. 2.4.1 could only be rescued by
    # cancelling the release run and re-dispatching by hand.
    it 'makes the Build Cloud opt-in reachable on the release trigger' do
      expr = builder_expression('release.yml').first

      expect(expr).to include('vars.'),
                      "release.yml resolves the driver as #{expr.inspect}. Dispatch inputs are empty on " \
                      'the release: published trigger, so the opt-in must also be readable from a ' \
                      'repository variable — otherwise the fast driver is unaskable on a real release.'
      expect(expr).to include('inputs.builder'),
                      'a re-dispatch must still be able to override the driver'
    end

    # Whichever path is taken, it must be visible. The original defect was a
    # silently-selected path; the same shape with the polarity reversed would
    # be just as bad.
    it 'records the selected driver in the run' do
      resolve = publish_steps.find { |step| step['run'].to_s.include?('GITHUB_STEP_SUMMARY') }

      expect(resolve).not_to be_nil,
                             'docker-publish.yml must write the resolved driver to the run summary, so the ' \
                             'path taken is never invisible'
      expect(resolve['run']).to include('::error::'),
                                'an unrecognised driver must fail loudly rather than fall through'
    end

    it 'lets a human override the driver on both workflows' do
      aggregate_failures do
        callers.each do |name|
          dispatch = workflow_on(name)['workflow_dispatch']
          expect(dispatch).to be_a(Hash), "#{name} must be dispatchable to override the driver"
          builder = dispatch.dig('inputs', 'builder')
          expect(builder).not_to be_nil, "#{name} must expose a builder input on workflow_dispatch"
          expect(builder['options']).to contain_exactly('cloud', 'emulated'),
                                        "#{name}'s builder input must offer both drivers"
          expect(builder['default']).to eq(default_builder),
                                        "#{name}'s dispatch default must be the free driver"
        end
      end
    end

    it 'keeps the Build Cloud endpoint overridable' do
      endpoint = publish_steps.find { |s| s.dig('with', 'driver') == 'cloud' }.dig('with', 'endpoint')

      expect(endpoint).to include('vars.'),
                          'the Build Cloud endpoint must come from a repository/org variable so it can be ' \
                          'repointed without editing the workflow'
    end

    it 'cancels superseded mainline builds but never a release publish' do
      aggregate_failures do
        expect(workflow_yaml('mainline.yml')['concurrency']['cancel-in-progress']).to be(true),
                                                                                      'mainline builds take about an hour, so pushes outpace them; superseded ' \
                                                                                      'master pushes must be cancelled rather than queued'
        expect(workflow_yaml('release.yml')['concurrency']['cancel-in-progress']).to be(false),
                                                                                     'a release publish must never be cancelled mid-flight - a half-pushed ' \
                                                                                     'manifest list is worse than a slow one'
      end
    end
  end

  describe 'publish job budget' do
    # The budget that failed was not wrong because 45 is a bad number; it was
    # wrong because it was applied to a driver that needs 65. Assert the
    # budget per driver, so "slow driver under the fast driver's budget" -
    # the exact shape of the 2.4.x outage - cannot be expressed.
    it 'budgets each driver against its own slowest measured build' do
      aggregate_failures do
        slowest_measured_minutes.each do |builder, slowest|
          budget = publish_budgets[builder]

          expect(budget).to be_a(Integer), "no timeout could be read for the #{builder} driver"
          expect(budget).to be >= slowest,
                            "the #{builder} budget is #{budget} minutes, below the slowest #{builder} " \
                            "build actually observed (#{slowest}) - it would cancel good builds, which " \
                            'is how 2.4.0, 2.4.1 and 2.4.2 were lost.'
          expect(budget).to be <= slowest * 3,
                            "the #{builder} budget is #{budget} minutes against a #{slowest}-minute " \
                            'worst case. Padding past 3x means a wedged build burns the runner instead ' \
                            'of reporting quickly.'
        end
      end
    end

    # This is the actionable core of the 2.4.x outage. The driver changed to
    # emulated and the budget stayed sized for Build Cloud: 20 minutes, then
    # 45, against a build that needs ~63. Assert the budget that applies to
    # the DEFAULT path, because that is the one every release gets.
    it 'sizes the default path budget for the default path' do
      budget = publish_budgets[default_builder]

      aggregate_failures do
        expect(budget).to be > failed_budgets.max,
                          "the #{default_builder} driver is budgeted #{budget} minutes, but " \
                          "#{failed_budgets.max} already timed out on that very path. A budget sized for " \
                          'a driver other than the default is what cancelled 2.4.0, 2.4.1 and 2.4.2.'
        expect(budget).to be >= slowest_measured_minutes[default_builder],
                          "the #{default_builder} budget is #{budget} minutes, below the slowest such " \
                          "build actually observed (#{slowest_measured_minutes[default_builder]})"
      end
    end

    it 'derives the budget from the driver instead of taking it from callers' do
      inputs = workflow_on('docker-publish.yml')['workflow_call']['inputs']

      expect(inputs).not_to have_key('timeout_minutes'),
                            'the budget must be derived from the driver inside docker-publish.yml, not ' \
                            'passed in. Two independent inputs can disagree, and a caller pairing the ' \
                            'emulated driver with a 25-minute budget is the 2.4.x bug rebuilt.'
      expect(workflow_yaml('docker-publish.yml')['jobs']['publish']['timeout-minutes'].to_s)
        .to include('inputs.builder'),
            'the job budget must be a function of inputs.builder'
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
