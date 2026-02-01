# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SearchQueryService do
  describe '.transform' do
    context 'with short queries' do
      it 'returns empty result for single character' do
        result = described_class.transform('a')

        expect(result[:ilike_terms]).to eq([])
        expect(result[:pg_search_term]).to eq('')
        expect(result[:normalized]).to eq('')
      end

      it 'returns empty result for empty string' do
        result = described_class.transform('')

        expect(result[:ilike_terms]).to eq([])
      end
    end

    context 'with normalization' do
      it 'splits PascalCase into words' do
        result = described_class.transform('RedHat')

        expect(result[:normalized]).to eq('Red Hat')
        expect(result[:ilike_terms]).to include('Red Hat')
      end

      it 'splits letter-number boundaries' do
        result = described_class.transform('RHEL9')

        expect(result[:normalized]).to eq('RHEL 9')
        expect(result[:ilike_terms]).to include('RHEL 9')
      end

      it 'normalizes dashes to spaces' do
        result = described_class.transform('RHEL-9')

        expect(result[:normalized]).to eq('RHEL 9')
      end

      it 'normalizes underscores to spaces' do
        result = described_class.transform('sshd_config')

        expect(result[:normalized]).to eq('sshd config')
      end

      it 'collapses multiple spaces' do
        result = described_class.transform('Red   Hat')

        expect(result[:normalized]).to eq('Red Hat')
      end
    end

    context 'with abbreviation expansion' do
      it 'expands RHEL to Red Hat Enterprise Linux' do
        result = described_class.transform('RHEL')

        expect(result[:ilike_terms]).to include('RHEL')
        expect(result[:ilike_terms]).to include('Red Hat Enterprise Linux')
      end

      it 'expands K8s to Kubernetes' do
        result = described_class.transform('K8s')

        expect(result[:ilike_terms]).to include('K8s')
        expect(result[:ilike_terms]).to include('Kubernetes')
      end
    end

    context 'with filename expansion' do
      it 'expands sshd.conf to include space-separated version' do
        result = described_class.transform('sshd.conf')

        expect(result[:ilike_terms]).to include('sshd.conf')
        expect(result[:ilike_terms]).to include('sshd conf')
        expect(result[:pg_search_term]).to eq('sshd conf')
      end

      it 'expands nginx.conf' do
        result = described_class.transform('nginx.conf')

        expect(result[:ilike_terms]).to include('nginx.conf')
        expect(result[:ilike_terms]).to include('nginx conf')
      end

      it 'expands config.yaml' do
        result = described_class.transform('config.yaml')

        expect(result[:ilike_terms]).to include('config.yaml')
        expect(result[:ilike_terms]).to include('config yaml')
      end

      it 'does not expand unknown extensions' do
        result = described_class.transform('file.xyz')

        expect(result[:ilike_terms]).to eq(['file.xyz'])
        expect(result[:pg_search_term]).to eq('file.xyz')
      end

      it 'does not expand non-filename patterns' do
        result = described_class.transform('some text')

        expect(result[:ilike_terms]).to include('some text')
        expect(result[:pg_search_term]).to eq('some text')
      end
    end

    context 'with combined transformations' do
      it 'handles RHEL9.conf pattern' do
        result = described_class.transform('RHEL9.conf')

        # Normalized: RHEL 9.conf (letter-number split)
        expect(result[:normalized]).to eq('RHEL 9.conf')
      end

      it 'returns unique terms' do
        result = described_class.transform('RHEL')

        expect(result[:ilike_terms]).to eq(result[:ilike_terms].uniq)
      end
    end
  end

  describe '.normalize' do
    it 'is idempotent' do
      input = 'RedHat Enterprise'
      first_pass = described_class.normalize(input)
      second_pass = described_class.normalize(first_pass)

      expect(first_pass).to eq(second_pass)
    end

    it 'preserves all-caps words' do
      result = described_class.normalize('RHEL STIG')

      expect(result).to eq('RHEL STIG')
    end

    it 'handles mixed case with numbers' do
      result = described_class.normalize('Win10Pro')

      expect(result).to eq('Win 10 Pro')
    end
  end

  describe '.expand_filenames' do
    it 'recognizes common config extensions' do
      %w[conf cfg config ini yaml yml json xml properties].each do |ext|
        result = described_class.expand_filenames("file.#{ext}")

        expect(result).to include("file #{ext}"),
                          "Expected file.#{ext} to expand to 'file #{ext}'"
      end
    end

    it 'recognizes script extensions' do
      %w[sh bash rb py].each do |ext|
        result = described_class.expand_filenames("script.#{ext}")

        expect(result).to include("script #{ext}")
      end
    end

    it 'does not expand paths with multiple dots' do
      # This is a limitation - we only match single word.extension
      result = described_class.expand_filenames('some.file.conf')

      # Won't match because pattern requires \A(\w+)\.ext\z
      expect(result).to eq(['some.file.conf'])
    end
  end
end
