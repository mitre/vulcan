# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: Export::Xccdf::VersionProfile is the ONE place XCCDF
# version variance lives — namespace, schemaLocation, and the
# format_id(type, raw) object-id encoding. The V1_1_4 profile emits
# today's exact values: the 1.1 namespace, the 1.1.4 schemaLocation
# string, and format_id as a pure passthrough for every id type. The
# formatter accepts a profile and defaults to V1_1_4.
# ==========================================================================
RSpec.describe Export::Xccdf::VersionProfile do
  describe 'V1_1_4' do
    subject(:profile) { described_class::V1_1_4 }

    it 'carries the 1.1 namespace' do
      expect(profile.namespace).to eq('http://checklists.nist.gov/xccdf/1.1')
    end

    it 'carries the 1.1.4 schemaLocation as valid whitespace-separated pairs' do
      expect(profile.schema_location).to eq(
        'http://checklists.nist.gov/xccdf/1.1 ' \
        'http://nvd.nist.gov/schema/xccdf-1.1.4.xsd ' \
        'http://cpe.mitre.org/dictionary/2.0 ' \
        'http://cpe.mitre.org/files/cpe-dictionary_2.1.xsd'
      )
      # Exactly four whitespace-separated tokens — the malformed pre-profile
      # string (missing space after the xsd) collapsed two into one.
      expect(profile.schema_location.split.size).to eq(4)
    end

    it 'format_id is a pure passthrough for every id type' do
      expect(profile.format_id(:benchmark, 'Corpus GPOS Component')).to eq('Corpus GPOS Component')
      expect(profile.format_id(:group, 'V-CORP-00-000001')).to eq('V-CORP-00-000001')
      expect(profile.format_id(:rule, 'SV-CORP-00-000001')).to eq('SV-CORP-00-000001')
      expect(profile.format_id(:fix, 'F-CORP-00-000001_fix')).to eq('F-CORP-00-000001_fix')
    end

    it 'is keyed 1.1.4 and frozen' do
      expect(profile.key).to eq('1.1.4')
      expect(profile).to be_frozen
    end
  end

  describe 'formatter integration' do
    it 'XccdfFormatter accepts a version profile and defaults to V1_1_4' do
      explicit = Export::Formatters::XccdfFormatter.new(version: described_class::V1_1_4)
      implicit = Export::Formatters::XccdfFormatter.new
      expect(explicit.version_profile).to be(described_class::V1_1_4)
      expect(implicit.version_profile).to be(described_class::V1_1_4)
    end
  end
end
