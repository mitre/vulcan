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

  # REQUIREMENT: seeded components should have representative PoC name + email
  # so the Settings page demo looks realistic. Currently admin_name / admin_email
  # are blank on most seed components.
  describe 'component PoC fields' do
    it 'sets admin_name on at least one seeded component' do
      expect(seeds).to match(/admin_name:\s*['"]/),
                       'expected at least one seeded component to have admin_name populated'
    end

    it 'sets admin_email on at least one seeded component' do
      expect(seeds).to match(/admin_email:\s*['"]/),
                       'expected at least one seeded component to have admin_email populated'
    end
  end

  # REQUIREMENT: seeded components should cover multiple comment_phase values so
  # the period banner + phase-gated UI are validatable without manual DB hacking.
  describe 'component phase coverage' do
    it 'sets comment_phase to "open" on at least one component' do
      expect(seeds).to match(/comment_phase:\s*['"]open['"]/),
                       'expected at least one component to have comment_phase: "open" for banner/icon coverage'
    end

    it 'sets comment_phase to "draft" on at least one component' do
      expect(seeds).to match(/comment_phase:\s*['"]draft['"]/),
                       'expected at least one component to have comment_phase: "draft" for phase-toggle coverage'
    end
  end
end
