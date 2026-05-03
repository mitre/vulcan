# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'seed file idempotency and completeness' do
  # REQUIREMENT: db/seeds.rb must be idempotent — running it twice must not
  # crash or create duplicate records. It must also create all expected data.
  #
  # Seeds must use find_or_create_by patterns, not create! which crashes on duplicates.
  # All Component.create calls must include a title (required field).

  include ConfigFileHelpers

  let(:seeds) { Rails.root.join('db/seeds.rb').read }

  describe 'idempotency' do
    it 'does not use bare create! for Projects' do
      project_creates = seeds.lines.grep(/Project\.create!/)
      non_idempotent = project_creates.reject { |l| l.include?('find_or_create_by') }
      expect(non_idempotent).to be_empty,
                                "Projects must use find_or_create_by!, not create!:\n#{non_idempotent.map(&:strip).join("\n")}"
    end

    it 'SRG/STIG seeding checks for existing records before save' do
      expect(seeds).to match(/find_by.*srg_id|find_by.*stig_id/),
                       'seed_xccdf must check for existing records before save!'
    end

    it 'does not use bare Membership.import without dedup' do
      expect(seeds).not_to match(/Membership\.import/),
                           'Memberships must use find_or_create_by, not bulk import (causes duplicates on re-run)'
    end
  end

  describe 'Component title requirement' do
    it 'all named Component.create/find_or_create calls include title' do
      # The seed_component helper must require title (either as a named param or via fetch)
      expect(seeds).to match(/def seed_component/).and(match(/\.fetch\(:title\)/)),
                       'seed_component helper must require title parameter'
    end
  end

  # REQUIREMENT (PR #717 follow-up): role-tier seed users for fast role-switching
  # in manual + Playwright testing. Email-as-role pattern mirrors the existing
  # admin@example.com convention. Goal: 30-second login/logout loop across tiers.
  describe 'role-tier seed users' do
    it 'creates viewer@example.com (commenter persona)' do
      expect(seeds).to include('viewer@example.com'),
                       'expected db/seeds.rb to create viewer@example.com'
    end

    it 'creates author@example.com (triager persona)' do
      expect(seeds).to include('author@example.com'),
                       'expected db/seeds.rb to create author@example.com'
    end

    it 'creates reviewer@example.com' do
      expect(seeds).to include('reviewer@example.com'),
                       'expected db/seeds.rb to create reviewer@example.com'
    end

    it 'guards role-user creation with an idempotent email lookup' do
      # Role users must be created via find_or_initialize_by(email:) (or similar)
      # so reruns don't crash on duplicate-email uniqueness violations. Combined
      # with the email-presence tests above, this confirms idempotent creation.
      expect(seeds).to match(/find_or_(initialize|create)_by!?\(email:/),
                       'expected db/seeds.rb to use find_or_initialize_by(email:) for role-user creation'
    end
  end

  # REQUIREMENT: every seeded component must carry representative PoC name + email
  # so the Settings page demo + projects/components pages render meaningfully
  # across all projects (not just Container Platform / Photon OS 4). Caught live
  # 2026-05-01 — projects 1 (Photon 3) and 5 (Nothing to See Here) had blank PoC.
  describe 'component PoC coverage' do
    let(:seed_component_calls) { seeds.scan(/seed_component\(.*?\n\)/m) }

    it 'has at least one seed_component call (sanity check)' do
      expect(seed_component_calls).not_to be_empty,
                                          'static-analysis regex must match the seed_component invocations'
    end

    it 'every seed_component call passes admin_name' do
      missing = seed_component_calls.reject { |call| call.include?('admin_name:') }
      expect(missing).to be_empty,
                         "seed_component calls without admin_name:\n#{missing.join("\n---\n")}"
    end

    it 'every seed_component call passes admin_email' do
      missing = seed_component_calls.reject { |call| call.include?('admin_email:') }
      expect(missing).to be_empty,
                         "seed_component calls without admin_email:\n#{missing.join("\n---\n")}"
    end

    it 'the dummy Component.create block includes admin_name' do
      # The "Nothing to See Here" 20.times loop creates filler components via
      # Component.create — those also need PoC so the demo has 100% coverage.
      # Match the multi-line call by anchoring on a closing `)` at line start.
      dummy_create = seeds[/Component\.create\(\s*\n.*?^\s*\)/m]
      expect(dummy_create).to be_present, 'expected to find the dummy Component.create block'
      expect(dummy_create).to include('admin_name:'),
                              "dummy Component.create must include admin_name:\n#{dummy_create}"
      expect(dummy_create).to include('admin_email:'),
                              "dummy Component.create must include admin_email:\n#{dummy_create}"
    end

    it 'backfills PoC on legacy components that pre-date this seed pass' do
      # Existing dummy components in dev DBs (created before PoC was seeded) must
      # be backfilled so reseeding actually populates them — the dummy create
      # block is gated on count < 20 so it doesn't re-run.
      expect(seeds).to match(/Component\.where\(admin_name:\s*\[nil/).or(match(/admin_name:\s*\[nil,\s*['"]\s*['"]\]/)),
                       'expected a backfill block for components missing admin_name'
    end
  end

  # Seeded components should cover the open/closed banner state so the
  # phase-gated UI is exercisable without manual DB hacking. Components
  # that omit comment_phase get the model default ("open"), so an
  # explicit comment_phase: 'open' with start/end dates is what the
  # banner needs to render.
  describe 'component phase coverage' do
    it 'sets comment_phase to "open" with comment_period dates on at least one component' do
      expect(seeds).to match(/comment_phase:\s*['"]open['"]/),
                       'expected at least one component to have comment_phase: "open" for banner/icon coverage'
      expect(seeds).to match(/comment_period_starts_at:/),
                       'expected at least one component to set comment_period_starts_at for banner coverage'
      expect(seeds).to match(/comment_period_ends_at:/),
                       'expected at least one component to set comment_period_ends_at for banner countdown coverage'
    end
  end
end
