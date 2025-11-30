# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Component XCCDF Import' do
  let(:project) { create(:project) }
  let(:srg) { create(:security_requirements_guide) }

  describe '#from_xccdf' do
    it 'imports XCCDF file and creates rules' do
      component = project.components.create!(
        name: 'XCCDF Import Test',
        version: 1,
        release: 1,
        prefix: 'TEST-00',
        security_requirements_guide_id: srg.id
      )

      temp_file = Tempfile.new(['test', '.xml'])
      temp_file.write(Rails.root.join('spec', 'fixtures', 'files', 'U_Web_Server_V2R3_Manual-xccdf.xml', 'U_Web_Server_V2R3_Manual-xccdf.xml', 'files', 'U_Web_Server_V2R3_Manual-xccdf.xml',
                                      'U_Web_Server_V2R3_Manual-xccdf.xml').read)
      temp_file.rewind

      xccdf_file = Rack::Test::UploadedFile.new(temp_file.path, 'application/xml')

      expect { component.from_xccdf(xccdf_file) }.to(change { component.rules.count })

      expect(component.rules.count).to be > 0
      expect(component.primary_controls_count).to be > 0

      temp_file.close
      temp_file.unlink
    end

    it 'parses XCCDF file and extracts metadata' do
      temp_file = Tempfile.new(['test', '.xml'])
      temp_file.write(Rails.root.join('spec', 'fixtures', 'files', 'U_Web_Server_V2R3_Manual-xccdf.xml', 'U_Web_Server_V2R3_Manual-xccdf.xml', 'files', 'U_Web_Server_V2R3_Manual-xccdf.xml',
                                      'U_Web_Server_V2R3_Manual-xccdf.xml').read)
      temp_file.rewind

      parsed = Xccdf::Benchmark.parse(File.read(temp_file.path))

      expect(parsed.group.count).to be > 0
      expect(parsed.title).to be_present

      temp_file.close
      temp_file.unlink
    end

    it 'handles satisfaction parsing for both formats' do
      component = project.components.create!(
        name: 'Test',
        prefix: 'TEST-00',
        security_requirements_guide_id: srg.id
      )

      expect { component.create_rule_satisfactions_from_xccdf }.not_to raise_error
    end
  end
end
