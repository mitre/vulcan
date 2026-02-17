# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: JsonArchiveFormatter produces a ZIP archive containing
# JSON files that preserve 100% of the component/rule object graph.
# Single-component exports have flat structure; multi-component exports
# have subdirectories under components/.
# ==========================================================================
RSpec.describe Export::Formatters::JsonArchiveFormatter do
  subject(:formatter) { described_class.new }

  describe 'interface' do
    it { expect(formatter.component_based?).to be true }
    it { expect(formatter.batch_generate?).to be true }
    it { expect(formatter.content_type).to eq('application/zip') }
    it { expect(formatter.file_extension).to eq('-backup.zip') }
  end

  describe '#generate_from_component' do
    subject(:data) { formatter.generate_from_component(component: component, rules: rules) }

    let(:component) { create(:component) }
    let(:rules) { component.rules }

    it 'returns binary zip data' do
      expect(data).to be_a(String)
      expect(data.encoding).to eq(Encoding::ASCII_8BIT)
    end

    it 'produces a valid zip archive' do
      entries = zip_entries(data)
      expect(entries).not_to be_empty
    end

    it 'contains manifest.json at root' do
      expect(zip_entries(data)).to include('manifest.json')
    end

    it 'contains component.json' do
      expect(zip_entries(data)).to include('component.json')
    end

    it 'contains rules.json' do
      expect(zip_entries(data)).to include('rules.json')
    end

    it 'contains satisfactions.json' do
      expect(zip_entries(data)).to include('satisfactions.json')
    end

    it 'contains reviews.json' do
      expect(zip_entries(data)).to include('reviews.json')
    end

    describe 'manifest.json contents' do
      subject(:manifest) { JSON.parse(zip_read(data, 'manifest.json')) }

      it 'has backup_format_version' do
        expect(manifest['backup_format_version']).to eq('1.0')
      end

      it 'has exported_at timestamp' do
        expect(manifest['exported_at']).to match(/\A\d{4}-\d{2}-\d{2}T/)
      end

      it 'has components array with manifest entry' do
        expect(manifest['components']).to be_an(Array)
        expect(manifest['components'].size).to eq(1)
        expect(manifest['components'].first['name']).to eq(component.name)
      end

      it 'includes SRG dependency in component manifest' do
        entry = manifest['components'].first
        expect(entry['srg_id']).to eq(component.based_on.srg_id)
        expect(entry['srg_title']).to eq(component.based_on.title)
      end
    end

    describe 'component.json contents' do
      subject(:comp_json) { JSON.parse(zip_read(data, 'component.json')) }

      it 'preserves component name' do
        expect(comp_json['name']).to eq(component.name)
      end

      it 'preserves component prefix' do
        expect(comp_json['prefix']).to eq(component.prefix)
      end

      it 'includes based_on SRG reference' do
        expect(comp_json['based_on']).to be_a(Hash)
        expect(comp_json['based_on']['srg_id']).to eq(component.based_on.srg_id)
      end
    end

    describe 'rules.json contents' do
      subject(:rules_json) { JSON.parse(zip_read(data, 'rules.json')) }

      it 'includes all rules' do
        expect(rules_json.size).to eq(component.rules.size)
      end

      it 'each rule has rule_id' do
        rules_json.each do |rule|
          expect(rule['rule_id']).to be_present
        end
      end

      it 'each rule has status' do
        rules_json.each do |rule|
          expect(rule['status']).to be_present
        end
      end

      it 'includes nested disa_rule_descriptions' do
        expect(rules_json.first['disa_rule_descriptions']).to be_an(Array)
      end

      it 'includes nested checks' do
        expect(rules_json.first['checks']).to be_an(Array)
      end
    end
  end

  describe '#generate_batch' do
    subject(:data) { formatter.generate_batch(component_rule_pairs: pairs) }

    let(:first_component) { create(:component) }
    let(:second_component) { create(:component, project: first_component.project) }
    let(:pairs) do
      [first_component, second_component].map do |c|
        { component: c, rules: c.rules }
      end
    end

    it 'returns binary zip data' do
      expect(data).to be_a(String)
    end

    it 'contains manifest.json with both components' do
      manifest = JSON.parse(zip_read(data, 'manifest.json'))
      expect(manifest['components'].size).to eq(2)
    end

    it 'contains project.json' do
      expect(zip_entries(data)).to include('project.json')
    end

    it 'has subdirectories for each component' do
      entries = zip_entries(data)
      component_dirs = entries.select { |e| e.start_with?('components/') && e.include?('component.json') }
      expect(component_dirs.size).to eq(2)
    end

    it 'each component directory contains all expected files' do
      entries = zip_entries(data)
      [first_component, second_component].each do |comp|
        dir = component_dir_for(comp)
        expect(entries).to include("components/#{dir}component.json")
        expect(entries).to include("components/#{dir}rules.json")
        expect(entries).to include("components/#{dir}satisfactions.json")
        expect(entries).to include("components/#{dir}reviews.json")
      end
    end

    describe 'project.json contents' do
      subject(:project_json) { JSON.parse(zip_read(data, 'project.json')) }

      it 'includes project name' do
        expect(project_json['name']).to eq(first_component.project.name)
      end

      it 'includes project description' do
        expect(project_json['description']).to eq(first_component.project.description)
      end
    end
  end

  private

  def zip_entries(data)
    entries = []
    Zip::File.open_buffer(StringIO.new(data)) do |zip|
      zip.each { |entry| entries << entry.name }
    end
    entries
  end

  def zip_read(data, name)
    Zip::File.open_buffer(StringIO.new(data)) do |zip|
      return zip.read(name)
    end
  end

  def component_dir_for(component)
    version = component.version ? "V#{component.version}" : ''
    release = component.release ? "R#{component.release}" : ''
    "#{component.name.tr(' ', '-')}-#{version}#{release}/"
  end
end
