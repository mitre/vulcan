# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExportHelper, type: :helper do
  include ExportHelper

  before(:all) do
    @component = FactoryBot.create(:component)
    @released_component = FactoryBot.create(:released_component)
    @project = @component.project
    @project_with_realeased_comp = @released_component.project
  end

  describe '#export_excel' do
    before(:all) do
      @workbook = export_excel(@project, 'released')
      @workbook_release_only = export_excel(@project_with_realeased_comp, 'relased')
      @workbook_release_all = export_excel(@project_with_realeased_comp, 'all')

      [@workbook, @workbook_release_only, @workbook_release_all].each_with_index do |item, index|
        file_name = ''
        if index == 0
          file_name = "./#{@project.name}.xlsx"
          File.binwrite(file_name, item.read_string)
          @xlsx = Roo::Spreadsheet.open(file_name)
        else
          file_name = "./#{@project_with_realeased_comp.name}.xlsx"
          File.binwrite(file_name, item.read_string)
          @xlsx_release_only = Roo::Spreadsheet.open(file_name) if index == 1
          @xlsx_release_all = Roo::Spreadsheet.open(file_name) if index == 2
        end
        File.delete(file_name)
      end
    end

    context 'in all scenarios' do
      it 'creates an excel format of a given project' do
        expect(@workbook).to be_present
        expect(@workbook.filename).to end_with 'xlsx'
      end
    end

    context 'when project has released component(s) and user requested only released components' do
      it 'creates an excel file with the # of sheets == # of released components' do
        expect(@xlsx_release_only.sheets.size).to eq @project_with_realeased_comp.components.where(released: true).size
      end

      it 'creates an excel file with correct format for worksheet name' do
        sheet_name = "#{@released_component.name}-V#{@released_component.version}"
        sheet_name += "R#{@released_component.release}-#{@released_component.id}"
        expect(@xlsx_release_only.sheets).to include(sheet_name)
      end
    end

    context 'When project has released component(s) and user requested to download all componenta' do
      it 'creates an excel file with the # of sheets == total # of components' do
        expect(@xlsx_release_all.sheets.size).to eq @project_with_realeased_comp.components.size
      end
    end

    context 'when project has no released component and user requested only released components' do
      it 'creates an empty spreadsheet' do
        expect(@xlsx.sheets.size).to eq 1
        expect(@xlsx.sheets.first).to eq 'Sheet1'
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
        title = (comp.title || "#{comp.name} STIG Readiness Guide")
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
        expect { YAML.parse(content) }.to_not raise_error
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
