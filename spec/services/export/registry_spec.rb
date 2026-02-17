# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: The export registry maps valid (mode, format) pairs to their
# implementing classes. Invalid combinations must be rejected.
#
# Valid combinations (from plan):
#   working_copy + csv, working_copy + excel,
#   vendor_submission + excel,
#   published_stig + xccdf, published_stig + inspec,
#   backup + xccdf
# ==========================================================================
RSpec.describe Export::Registry do
  describe '.valid?' do
    it 'accepts working_copy + csv' do
      expect(described_class.valid?(:working_copy, :csv)).to be true
    end

    it 'accepts working_copy + excel' do
      expect(described_class.valid?(:working_copy, :excel)).to be true
    end

    it 'accepts vendor_submission + excel' do
      expect(described_class.valid?(:vendor_submission, :excel)).to be true
    end

    it 'accepts published_stig + xccdf' do
      expect(described_class.valid?(:published_stig, :xccdf)).to be true
    end

    it 'accepts published_stig + inspec' do
      expect(described_class.valid?(:published_stig, :inspec)).to be true
    end

    it 'accepts backup + xccdf' do
      expect(described_class.valid?(:backup, :xccdf)).to be true
    end

    it 'rejects working_copy + xccdf (not a valid combination)' do
      expect(described_class.valid?(:working_copy, :xccdf)).to be false
    end

    it 'rejects vendor_submission + csv (not a valid combination)' do
      expect(described_class.valid?(:vendor_submission, :csv)).to be false
    end

    it 'rejects unknown mode' do
      expect(described_class.valid?(:nonexistent, :csv)).to be false
    end

    it 'rejects unknown format' do
      expect(described_class.valid?(:working_copy, :pdf)).to be false
    end
  end

  describe '.mode_class' do
    it 'returns WorkingCopy class for :working_copy' do
      expect(described_class.mode_class(:working_copy)).to eq Export::Modes::WorkingCopy
    end

    it 'raises for unknown mode' do
      expect { described_class.mode_class(:nonexistent) }.to raise_error(Export::Registry::InvalidCombination)
    end
  end

  describe '.formatter_class' do
    it 'returns CsvFormatter class for :csv' do
      expect(described_class.formatter_class(:csv)).to eq Export::Formatters::CsvFormatter
    end

    it 'raises for unknown format' do
      expect { described_class.formatter_class(:pdf) }.to raise_error(Export::Registry::InvalidCombination)
    end
  end

  describe '.formats_for' do
    it 'returns [:csv, :excel] for working_copy' do
      expect(described_class.formats_for(:working_copy)).to contain_exactly(:csv, :excel)
    end

    it 'returns empty array for unknown mode' do
      expect(described_class.formats_for(:nonexistent)).to eq []
    end
  end
end
