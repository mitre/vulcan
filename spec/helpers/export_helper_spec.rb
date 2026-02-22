# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExportHelper do
  include ExportHelper

  # Use let_it_be to create the expensive component once (SRG XML parse + rule import).
  # Previously used before(:all) which leaked records outside DatabaseCleaner transactions.
  let_it_be(:component) { create(:component) }
  let_it_be(:project) { component.project }

  let(:component_ids) { project.components.ids.join(',') }

  describe '#export_excel' do
    # Generate workbooks once and read binary string immediately (FastExcel temp dirs are ephemeral)
    let_it_be(:excel_binaries) do
      helper = Object.new.extend(ExportHelper)
      comp = Component.first
      proj = comp.project
      ids = proj.components.ids.join(',')
      normal_wb = helper.export_excel(proj, ids, false)
      disa_wb = helper.export_excel(proj, ids, true)
      {
        normal: normal_wb.read_string,
        disa: disa_wb.read_string,
        normal_filename: normal_wb.filename,
        disa_filename: disa_wb.filename
      }
    end

    let(:xlsx) { read_xlsx(excel_binaries[:normal]) }
    let(:xlsx_disa) { read_xlsx(excel_binaries[:disa]) }

    context 'in all scenarios' do
      it 'creates an excel format of a given project' do
        expect(excel_binaries[:normal]).to be_present
        expect(excel_binaries[:normal_filename]).to end_with 'xlsx'
        expect(excel_binaries[:disa]).to be_present
        expect(excel_binaries[:disa_filename]).to end_with 'xlsx'
      end

      it 'creates an excel file with the # sheets == # of components that was requested for export' do
        expect(xlsx.sheets.size).to eq component_ids.split(',').size
        expect(xlsx_disa.sheets.size).to eq component_ids.split(',').size
      end
    end

    context 'When a user request a DISA excel export' do
      it 'does not include a column for "InSpec Control Body"' do
        parsed = xlsx_disa.sheet(0).parse(headers: true).drop(1)
        expect(parsed.first).not_to include 'InSpec Control Body'
      end

      it 'returns empty values for "Status Justification", "Mitigation",and "Artifact Description" columns if
        the rule status is "Applicable - Configurable"' do
        parsed = xlsx_disa.sheet(0).parse(headers: true).drop(1)
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
        parsed = xlsx_disa.sheet(0).parse(headers: true).drop(1)
        mitigations = parsed.filter_map do |row|
          next if row['Status'] != 'Applicable - Inherently Meets'

          row['Mitigation']
        end
        expect(mitigations).to be_empty
      end

      it 'returns emty values for "Mitigation, Artifact Description" column if rule (row) status is "Not Applicable"' do
        parsed = xlsx_disa.sheet(0).parse(headers: true).drop(1)
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
    let(:zip_data) { export_xccdf_project(project).string }

    it 'creates a zip file containing all components of a project in xccdf format' do
      entries = zip_entries(zip_data)
      expect(entries.size).to eq project.components.size

      # check the content of each file is valid xml
      errors = []
      Zip::File.open_buffer(StringIO.new(zip_data)) do |zip|
        zip.each do |xml|
          xml.get_input_stream { |io| errors << Nokogiri::XML(io.read).errors }
        end
      end
      expect(errors).to all(be_empty)
    end

    it 'creates a zip file containing xccdf files with correct name format' do
      expected_names = project.components.map do |comp|
        version = comp.version ? "V#{comp.version}" : ''
        release = comp.release ? "R#{comp.release}" : ''
        title = comp.title || "#{comp.name} STIG Readiness Guide"
        "U_#{title.tr(' ', '_')}_#{version}#{release}-xccdf.xml"
      end
      entries = zip_entries(zip_data)
      expect(entries.sort).to eq expected_names.sort
    end
  end

  describe '#export_inspec_project' do
    let(:zip_data) { export_inspec_project(project).string }

    it 'creates a zip file containing all components of a project in YAML format' do
      entries = zip_entries(zip_data)
      expect(entries.size).to eq project.components.size

      # ensure files are valid yaml
      Zip::File.open_buffer(StringIO.new(zip_data)) do |zip|
        zip.each do |yml|
          content = nil
          yml.get_input_stream { |io| content = io.read }
          expect { YAML.parse(content) }.not_to raise_error
        end
      end
    end

    it 'creates a zip file containing yaml files with correct name format' do
      expected_names = project.components.map do |comp|
        version = comp.version ? "V#{comp.version}" : ''
        release = comp.release ? "R#{comp.release}" : ''

        "#{comp.name.tr(' ', '-')}-#{version}#{release}-stig-baseline/inspec.yml"
      end
      entries = zip_entries(zip_data)
      expect(entries.sort).to eq expected_names.sort
    end
  end
end
