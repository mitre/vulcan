# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: End-to-end integration tests verifying Export::Base produces
# correct output for published_stig mode with XCCDF and InSpec formatters.
# These tests go through the full pipeline: Base → Mode → Formatter → Result.
# ==========================================================================
RSpec.describe 'PublishedStig integration' do
  let(:component) { create(:component) }
  let(:status_ac) { 'Applicable - Configurable' }
  let(:zip_content_type) { 'application/zip' }

  before do
    # Set up mixed statuses
    rules = component.rules.order(:rule_id).to_a
    raise StandardError, 'Need at least 3 rules' if rules.size < 3

    rules[0].update_columns(status: status_ac)
    rules[0].update_inspec_code
    rules[1].update_columns(status: status_ac)
    rules[1].update_inspec_code
    rules[2].update_columns(status: 'Not Applicable')
  end

  describe 'XCCDF export' do
    it 'produces a Result with XML data containing only AC rules' do
      result = Export::Base.new(
        exportable: component, mode: :published_stig, format: :xccdf
      ).call

      expect(result).to be_a(Export::Result)
      expect(result.content_type).to eq('application/xml')
      expect(result.data).to include('<Benchmark')

      # Should have 2 groups (2 AC rules)
      expect(result.data.scan('<Group').count).to eq(2)
    end

    it 'excludes satisfied_by rules' do
      rules = component.rules.order(:rule_id).to_a
      # Make rules[1] satisfied_by rules[0]
      RuleSatisfaction.create!(rule_id: rules[1].id, satisfied_by_rule_id: rules[0].id)

      result = Export::Base.new(
        exportable: component, mode: :published_stig, format: :xccdf
      ).call

      # Only 1 group now (rules[0] is AC, rules[1] is AC but satisfied_by)
      expect(result.data.scan('<Group').count).to eq(1)
    end
  end

  describe 'InSpec export' do
    it 'produces a Result with zip data' do
      result = Export::Base.new(
        exportable: component, mode: :published_stig, format: :inspec
      ).call

      expect(result).to be_a(Export::Result)
      expect(result.content_type).to eq(zip_content_type)
      expect(result.data).to be_a(String)
      expect(result.data.size).to be > 0
    end

    it 'zip contains inspec.yml and control files for AC rules only' do
      result = Export::Base.new(
        exportable: component, mode: :published_stig, format: :inspec
      ).call

      entries = []
      Zip::File.open_buffer(StringIO.new(result.data)) do |zip|
        zip.each { |entry| entries << entry.name }
      end

      yml_files = entries.select { |e| e.end_with?('inspec.yml') }
      expect(yml_files.size).to eq(1)
      control_files = entries.select { |e| e.end_with?('.rb') }
      expect(control_files.size).to eq(2) # 2 AC rules
    end
  end

  describe 'project-level XCCDF export' do
    let(:project) { component.project }

    it 'produces a zipped Result for multi-component project' do
      component2 = create(:component, project: project)
      component2.rules.first.update_columns(status: status_ac)

      result = Export::Base.new(
        exportable: project, mode: :published_stig, format: :xccdf
      ).call

      # Multi-component = zip
      expect(result.content_type).to eq(zip_content_type)
      entries = []
      Zip::File.open_buffer(StringIO.new(result.data)) do |zip|
        zip.each { |entry| entries << entry.name }
      end
      expect(entries.size).to eq(2)
      expect(entries.all? { |e| e.end_with?('-xccdf.xml') }).to be true
    end
  end

  describe 'project-level InSpec export' do
    let(:project) { component.project }

    it 'produces a single zip with subdirectories' do
      component2 = create(:component, project: project)
      component2.rules.first.update_columns(status: status_ac)
      component2.rules.first.update_inspec_code

      result = Export::Base.new(
        exportable: project, mode: :published_stig, format: :inspec
      ).call

      expect(result.content_type).to eq(zip_content_type)
      entries = []
      Zip::File.open_buffer(StringIO.new(result.data)) do |zip|
        zip.each { |entry| entries << entry.name }
      end
      # Should have 2 inspec.yml files (one per component subdirectory)
      yml_files = entries.select { |e| e.end_with?('inspec.yml') }
      expect(yml_files.size).to eq(2)
    end
  end
end
