# frozen_string_literal: true

require 'rails_helper'
require 'zip'

RSpec.describe Import::JsonArchive::Merge::MergeInput, type: :service do
  let(:component_data) do
    { 'name' => 'C1', 'prefix' => 'AAAA-00', 'version' => '1', 'release' => '1' }
  end
  let(:rules_data) { [{ 'rule_id' => 'V-1', 'title' => 'r1' }] }
  let(:satisfactions_data) { [{ 'rule_id' => 'V-1', 'satisfied_by_rule_id' => 'V-2' }] }
  let(:reviews_data) { [{ 'rule_id' => 'V-1', 'comment' => 'hi', 'created_at' => '2026-06-06T10:23:45.123456' }] }
  let(:single_component_slice) do
    {
      'component' => component_data,
      'rules' => rules_data,
      'satisfactions' => satisfactions_data,
      'reviews' => reviews_data
    }
  end

  describe '.from_json_archive' do
    it 'normalizes a single-component archive slice into the MergeInput shape' do
      input = described_class.from_json_archive(single_component_slice)

      expect(input.format).to eq(:json_archive)
      expect(input.component_meta).to include('name' => 'C1')
      expect(input.rules).to eq(rules_data)
      expect(input.reviews).to eq(reviews_data)
      expect(input.satisfactions).to eq(satisfactions_data)
    end

    it 'coerces nil arrays to empty arrays' do
      slice = { 'component' => component_data, 'rules' => nil, 'satisfactions' => nil, 'reviews' => nil }

      input = described_class.from_json_archive(slice)

      expect(input.rules).to eq([])
      expect(input.satisfactions).to eq([])
      expect(input.reviews).to eq([])
    end

    it 'accepts symbol-keyed hashes (deep_stringify before slicing)' do
      slice = {
        component: { name: 'C1' },
        rules: [{ rule_id: 'V-1' }],
        satisfactions: [],
        reviews: []
      }

      input = described_class.from_json_archive(slice)

      expect(input.component_meta).to eq('name' => 'C1')
      expect(input.rules.first).to eq('rule_id' => 'V-1')
    end

    it 'raises ArgumentError when component key is missing' do
      expect { described_class.from_json_archive({ 'rules' => [], 'satisfactions' => [], 'reviews' => [] }) }
        .to raise_error(ArgumentError, /component/i)
    end
  end

  describe '.from_spreadsheet' do
    let(:component) { create(:component, :skip_rules) }

    it 'applies HEADER_ALIASES so DISA-flavored headers normalize to import headers' do
      rows = [
        { 'STIG ID' => 'V-100', 'SRG ID' => 'SRG-OS-1', 'Title' => 'A', 'Check Content' => 'do x', 'Fix Text' => 'do y' }
      ]

      input = described_class.from_spreadsheet(rows, component: component)

      expect(input.format).to eq(:spreadsheet)
      expect(input.rules.first).to include('STIGID' => 'V-100', 'SRGID' => 'SRG-OS-1', 'Requirement' => 'A',
                                           'Check' => 'do x', 'Fix' => 'do y')
      expect(input.reviews).to eq([])
      expect(input.satisfactions).to eq([])
    end

    it 'normalizes shape: same accessor surface as from_json_archive' do
      rows = [{ 'STIGID' => 'V-200' }]

      input = described_class.from_spreadsheet(rows, component: component)

      expect(input).to respond_to(:rules, :reviews, :satisfactions, :component_meta, :memberships, :manifest)
      expect(input.component_meta).to include('name' => component.name)
    end
  end

  describe '.from_zip_path' do
    def build_zip(files)
      tmp = Tempfile.new(['archive', '.zip'])
      tmp.close
      Zip::File.open(tmp.path, Zip::File::CREATE) do |zip|
        files.each { |path, content| zip.get_output_stream(path) { |s| s.write(content) } }
      end
      tmp.path
    end

    let(:manifest_json) do
      { backup_format_version: '1.0', vulcan_version: 'test', components: [] }.to_json
    end
    let(:files) do
      {
        'manifest.json' => manifest_json,
        'component.json' => component_data.to_json,
        'rules.json' => rules_data.to_json,
        'satisfactions.json' => satisfactions_data.to_json,
        'reviews.json' => reviews_data.to_json
      }
    end

    it 'parses a flat (single-component) archive layout' do
      input = described_class.from_zip_path(build_zip(files))

      expect(input.rules).to eq(rules_data)
      expect(input.satisfactions).to eq(satisfactions_data)
      expect(input.reviews).to eq(reviews_data)
      expect(input.component_meta).to include('name' => 'C1')
    end

    it 'parses a nested (multi-component) archive layout — satisfactions not silently dropped' do
      nested = {
        'manifest.json' => manifest_json,
        'components/C1-V1R1/component.json' => component_data.to_json,
        'components/C1-V1R1/rules.json' => rules_data.to_json,
        'components/C1-V1R1/satisfactions.json' => satisfactions_data.to_json,
        'components/C1-V1R1/reviews.json' => reviews_data.to_json
      }

      input = described_class.from_zip_path(build_zip(nested))

      expect(input.satisfactions).to eq(satisfactions_data)
      expect(input.rules).to eq(rules_data)
      expect(input.reviews).to eq(reviews_data)
    end

    it 'raises ArgumentError when the zip has no component.json at any layout' do
      bare = build_zip('manifest.json' => manifest_json)

      expect { described_class.from_zip_path(bare) }.to raise_error(ArgumentError, /component/i)
    end
  end

  describe 'construction validation' do
    it 'raises ArgumentError on an unknown format' do
      expect { described_class.new(format: :csv_dump, component_meta: {}, rules: []) }
        .to raise_error(ArgumentError, /format/i)
    end
  end
end
