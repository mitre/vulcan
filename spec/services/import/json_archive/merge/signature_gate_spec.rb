# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::JsonArchive::Merge::SignatureGate do
  # Sync settings live under Settings.sync; tests build a fresh stand-in
  # per example so we don't lean on whatever real config/vulcan.yml ships.
  def stub_sync_setting(require_signed:)
    sync_double = double('sync_settings')
    allow(sync_double).to receive(:[]).with('require_signed_archives').and_return(require_signed)
    allow(sync_double).to receive(:require_signed_archives).and_return(require_signed)
    allow(Settings).to receive(:sync).and_return(sync_double)
  end

  let(:manifest_unsigned) do
    { 'backup_format_version' => '1.1', 'components' => [] }
  end

  let(:manifest_signed) do
    { 'backup_format_version' => '1.1', 'components' => [], 'signature' => 'deadbeef' }
  end

  describe '.required?' do
    it 'is false when the setting is unset (default behavior preserved)' do
      stub_sync_setting(require_signed: nil)
      expect(described_class.required?).to be false
    end

    it 'is false when the setting is explicitly false' do
      stub_sync_setting(require_signed: false)
      expect(described_class.required?).to be false
    end

    it 'is true when the setting is true' do
      stub_sync_setting(require_signed: true)
      expect(described_class.required?).to be true
    end

    it 'is false when Settings.sync is absent entirely' do
      allow(Settings).to receive(:sync).and_return(nil)
      expect(described_class.required?).to be false
    end
  end

  describe '.verify!' do
    context 'when the gate is off' do
      before { stub_sync_setting(require_signed: false) }

      it 'passes regardless of signature presence' do
        expect(described_class.verify!(manifest_unsigned)).to be true
        expect(described_class.verify!(manifest_signed)).to be true
      end
    end

    context 'when the gate is on' do
      before { stub_sync_setting(require_signed: true) }

      it 'raises MissingSignatureError when signature is absent' do
        expect { described_class.verify!(manifest_unsigned) }
          .to raise_error(described_class::MissingSignatureError, /missing a signature/i)
      end

      it 'raises when signature is blank' do
        expect { described_class.verify!(manifest_unsigned.merge('signature' => '   ')) }
          .to raise_error(described_class::MissingSignatureError)
      end

      it 'passes when signature is a non-blank string (presence only — no HMAC check yet)' do
        expect(described_class.verify!(manifest_signed)).to be true
      end
    end
  end

  describe '.verify' do
    before { stub_sync_setting(require_signed: true) }

    it 'returns false on missing signature instead of raising' do
      expect(described_class.verify(manifest_unsigned)).to be false
    end

    it 'returns true when signature is present' do
      expect(described_class.verify(manifest_signed)).to be true
    end
  end
end
