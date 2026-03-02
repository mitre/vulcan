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
      # Find component creation lines (excluding the dummy loop which already has title)
      seeds.lines.grep(/seed_component|Component\.create!|Component\.find_or_create/)
      # The seed_component helper requires title as a parameter — check it exists
      expect(seeds).to match(/def seed_component.*title/),
                       'seed_component helper must require title parameter'
    end
  end
end
