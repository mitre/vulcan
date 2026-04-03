# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SearchAbbreviationService do
  let(:rhel_expansion) { 'Red Hat Enterprise Linux' }
  let(:acme_expansion) { 'ACME Corporation' }

  before do
    # Clear cache before each test
    described_class.clear_cache!
  end

  describe '.core_abbreviations' do
    it 'loads abbreviations from config file' do
      core = described_class.send(:core_abbreviations)
      expect(core).to be_a(Hash)
      expect(core['RHEL']).to eq(rhel_expansion)
      expect(core['K8s']).to eq('Kubernetes')
    end

    it 'returns empty hash if config file missing' do
      allow(File).to receive(:exist?).and_return(false)
      core = described_class.send(:core_abbreviations)
      expect(core).to eq({})
    end

    it 'safely rejects malicious YAML (uses safe_load, not load_file)' do
      # Security fix: YAML.safe_load prevents arbitrary object deserialization
      malicious_yaml = Rails.root.join('tmp/malicious_abbrev_test.yml')
      malicious_content = <<~YAML
        abbreviations:
          TEST: !ruby/object:Gem::Requirement
            requirements:
              !ruby/object:Gem::Package::TarReader
              io: !ruby/object:Net::BufferedIO
      YAML

      File.write(malicious_yaml, malicious_content)

      allow(Rails.root).to receive(:join).with('config/search_abbreviations.yml')
                                         .and_return(malicious_yaml)

      # safe_load rejects malicious objects, returns {} via rescue block
      result = described_class.send(:core_abbreviations)
      expect(result).to eq({})

      FileUtils.rm_f(malicious_yaml)
    end

    it 'safely loads valid YAML with Symbol keys' do
      valid_yaml = Rails.root.join('tmp/valid_abbrev_test.yml')
      valid_content = <<~YAML
        abbreviations:
          TEST: Test Expansion
          RHEL: #{rhel_expansion}
      YAML

      File.write(valid_yaml, valid_content)

      allow(Rails.root).to receive(:join).with('config/search_abbreviations.yml')
                                         .and_return(valid_yaml)

      result = described_class.send(:core_abbreviations)
      expect(result).to eq({
                             'TEST' => 'Test Expansion',
                             'RHEL' => rhel_expansion
                           })

      FileUtils.rm_f(valid_yaml)
    end
  end

  describe '.user_abbreviations' do
    it 'returns empty hash when no user abbreviations exist' do
      user = described_class.send(:user_abbreviations)
      expect(user).to eq({})
    end

    it 'loads active user abbreviations from database' do
      create(:search_abbreviation, abbreviation: 'ACME', expansion: acme_expansion)
      user = described_class.send(:user_abbreviations)
      expect(user['ACME']).to eq(acme_expansion)
    end

    it 'excludes inactive abbreviations' do
      create(:search_abbreviation, abbreviation: 'INACTIVE', expansion: 'Should Not Appear', active: false)
      user = described_class.send(:user_abbreviations)
      expect(user).not_to have_key('INACTIVE')
    end
  end

  describe '.all' do
    it 'returns core abbreviations' do
      all = described_class.all
      expect(all['RHEL']).to eq(rhel_expansion)
    end

    it 'includes user abbreviations' do
      create(:search_abbreviation, abbreviation: 'ACME', expansion: acme_expansion)
      described_class.clear_cache!

      all = described_class.all
      expect(all['ACME']).to eq(acme_expansion)
    end

    it 'user abbreviations override core' do
      create(:search_abbreviation, abbreviation: 'RHEL', expansion: 'Custom RHEL Definition')
      described_class.clear_cache!

      all = described_class.all
      expect(all['RHEL']).to eq('Custom RHEL Definition')
    end

    it 'caches the result' do
      # Use memory store for this test to verify caching behavior
      memory_cache = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(memory_cache)

      # First call populates cache
      described_class.all

      # Directly insert into DB without triggering callbacks (to test cache isolation)
      SearchAbbreviation.insert({ abbreviation: 'NEWCACHE', expansion: 'New Abbreviation', active: true, created_at: Time.current, updated_at: Time.current })

      # Should still use cached version (abbreviation not in cache yet)
      all = described_class.all
      expect(all).not_to have_key('NEWCACHE')

      # After clearing cache, should include new abbreviation
      described_class.clear_cache!
      all = described_class.all
      expect(all['NEWCACHE']).to eq('New Abbreviation')
    end
  end

  describe '.expand_query' do
    it 'returns original query in result' do
      result = described_class.expand_query('RHEL')
      expect(result).to include('RHEL')
    end

    it 'expands known abbreviation' do
      result = described_class.expand_query('RHEL')
      expect(result).to include(rhel_expansion)
    end

    it 'handles case-insensitive matching' do
      result = described_class.expand_query('rhel')
      expect(result).to include(rhel_expansion)
    end

    it 'expands multiple abbreviations in query' do
      result = described_class.expand_query('RHEL K8s')
      expect(result).to include(rhel_expansion)
      expect(result).to include('Kubernetes')
    end

    it 'does not expand unknown terms' do
      result = described_class.expand_query('UNKNOWN')
      expect(result).to eq(['UNKNOWN'])
    end

    it 'handles mixed known and unknown terms' do
      result = described_class.expand_query('RHEL UNKNOWN')
      expect(result).to include('RHEL UNKNOWN')
      expect(result).to include(rhel_expansion)
      expect(result.length).to eq(2)
    end

    it 'uses user abbreviations' do
      create(:search_abbreviation, abbreviation: 'ACME', expansion: acme_expansion)
      described_class.clear_cache!

      result = described_class.expand_query('ACME')
      expect(result).to include(acme_expansion)
    end

    it 'user abbreviations override core in expansion' do
      create(:search_abbreviation, abbreviation: 'RHEL', expansion: 'Our Custom RHEL')
      described_class.clear_cache!

      result = described_class.expand_query('RHEL')
      expect(result).to include('Our Custom RHEL')
      expect(result).not_to include(rhel_expansion)
    end
  end

  describe '.clear_cache!' do
    it 'clears the cached abbreviations' do
      # Populate cache
      described_class.all

      # Clear and verify it reloads
      expect(Rails.cache).to receive(:delete).with(described_class::CACHE_KEY)
      described_class.clear_cache!
    end
  end
end
