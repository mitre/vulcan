# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExportHelper, type: :helper do
  include ExportHelper

  before(:all) do
    @component = create(:component)
    @project = @component.project
    @component_ids = @project.components.pluck(:id).join(',')
  end

  describe '#export_excel' do
    before(:all) do
      @workbook = export_excel(@project, @component_ids, false)
      @workbook_disa_export = export_excel(@project, @component_ids, true)

      [@workbook, @workbook_disa_export].each_with_index do |item, index|
        file_name = ''
        if index == 0
          file_name = "./#{@project.name}.xlsx"
          File.binwrite(file_name, item.read_string)
          @xlsx = Roo::Spreadsheet.open(file_name)
        else
          file_name = "./#{@project.name}_DISA.xlsx"
          File.binwrite(file_name, item.read_string)
          @xlsx_disa = Roo::Spreadsheet.open(file_name)
        end
        File.delete(file_name)
      end
    end

    context 'in all scenarios' do
      it 'creates an excel format of a given project' do
        expect(@workbook).to be_present
        expect(@workbook.filename).to end_with 'xlsx'
        expect(@workbook_disa_export).to be_present
        expect(@workbook_disa_export.filename).to end_with 'xlsx'
      end

      it 'creates an excel file with the # sheets == # of components that was requested for export' do
        expect(@xlsx.sheets.size).to eq @component_ids.split(',').size
        expect(@xlsx_disa.sheets.size).to eq @component_ids.split(',').size
      end
    end

    context 'When a user request a DISA excel export' do
      it 'does not include a column for "InSpec Control Body"' do
        parsed = @xlsx_disa.sheet(0).parse(headers: true).drop(1)
        expect(parsed.first).not_to include 'InSpec Control Body'
      end

      it 'returns empty values for "Status Justification", "Mitigation",and "Artifact Description" columns if
        the rule status is "Applicable - Configurable"' do
        parsed = @xlsx_disa.sheet(0).parse(headers: true).drop(1)
        status_justifications = parsed.filter_map do |row|
          next if row['Status'] != 'Applicable - Configurable'

          row['Status Justification']
        end
        mitigations = parsed.filter_map do |row|
          next if row['Status'] != 'Applicable - Configurable'

          row['Mitigation']
        end
        artifact_descriptions = parsed.filter_map do |row|
          next if row['Status'] != 'Applicable - Configurable'

          row['Artifact Description']
        end
        expect(status_justifications).to be_empty
        expect(mitigations).to be_empty
        expect(artifact_descriptions).to be_empty
      end

      it 'returns emty values for "Mitigation" column if rule (row) status is "Applicable - Inherently Meets"' do
        parsed = @xlsx_disa.sheet(0).parse(headers: true).drop(1)
        mitigations = parsed.filter_map do |row|
          next if row['Status'] != 'Applicable - Inherently Meets'

          row['Mitigation']
        end
        expect(mitigations).to be_empty
      end

      it 'returns emty values for "Mitigation, Artifact Description" column if rule (row) status is "Not Applicable"' do
        parsed = @xlsx_disa.sheet(0).parse(headers: true).drop(1)
        mitigations = parsed.filter_map do |row|
          next if row['Status'] != 'Not Applicable'

          row['Mitigation']
        end
        artifact_descriptions = parsed.filter_map do |row|
          next if row['Status'] != 'Not Applicable'

          row['Artifact Description']
        end
        expect(mitigations).to be_empty
        expect(artifact_descriptions).to be_empty
      end
    end
  end

  describe '#export_xccdf_project' do
    before(:all) do
      @file_name = "./#{@project.name}.zip"
      File.binwrite(@file_name, export_xccdf_project(@project).string)
      @zip = Zip::File.open(@file_name)
    end

    after(:all) do
      File.delete(@file_name)
    end

    it 'creates a zip file containing all components of a project in xccdf format' do
      expect(@zip.size).to eq @project.components.size
      # check the content of each file is valid xml
      errors = []
      @zip.each do |xml|
        xml.get_input_stream { |io| errors << Nokogiri::XML(io.read).errors }
      end
      expect(errors).to all(be_empty)
    end

    it 'creates a zip file containing xccdf files with correct name format' do
      expected_names = @project.components.map do |comp|
        version = comp.version ? "V#{comp.version}" : ''
        release = comp.release ? "R#{comp.release}" : ''
        title = comp.title || "#{comp.name} STIG Readiness Guide"
        "U_#{title.tr(' ', '_')}_#{version}#{release}-xccdf.xml"
      end
      expect(@zip.map(&:name).sort).to eq expected_names.sort
    end
  end

  describe '#export_inspec_project' do
    before(:all) do
      @file_name = "./#{@project.name}.zip"
      File.binwrite(@file_name, export_inspec_project(@project).string)
      @zip = Zip::File.open(@file_name)
    end

    after(:all) do
      File.delete(@file_name)
    end

    it 'creates a zip file containing all components of a project in YAML format' do
      expect(@zip.size).to eq @project.components.size
      # ensure files are valid yaml
      @zip.each do |yml|
        content = nil
        yml.get_input_stream { |io| content = io.read }
        expect { YAML.parse(content) }.not_to raise_error
      end
    end

    it 'creates a zip file containing yaml files with correct name format' do
      expected_names = @project.components.map do |comp|
        version = comp.version ? "V#{comp.version}" : ''
        release = comp.release ? "R#{comp.release}" : ''

        "#{comp.name.tr(' ', '-')}-#{version}#{release}-stig-baseline/inspec.yml"
      end

      expect(@zip.map(&:name).sort).to eq expected_names.sort
    end
  end
end
