# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Component XCCDF Import', type: :request do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:srg) { create(:security_requirements_guide) }
  let(:xccdf_file) { fixture_file_upload('U_Web_Server_V2R3_Manual-xccdf.xml', 'application/xml') }

  before do
    sign_in user
    project.memberships.create(user: user, role: 'admin')
    Rails.application.reload_routes!
  end

  describe 'POST /projects/:project_id/components' do
    context 'with valid XCCDF file' do
      it 'creates component from XCCDF file' do
        expect do
          post "/projects/#{project.id}/components", params: {
            component: {
              security_requirements_guide_id: srg.id,
              file: xccdf_file
            }
          }
        end.to change(Component, :count).by(1)

        expect(response).to have_http_status(:redirect)

        component = Component.last
        expect(component.name).to be_present
        expect(component.prefix).to be_present
        expect(component.rules.count).to be > 0
      end

      it 'extracts metadata from XCCDF benchmark' do
        post "/projects/#{project.id}/components", params: {
          component: {
            security_requirements_guide_id: srg.id,
            file: xccdf_file
          }
        }

        component = Component.last
        expect(component.title).to be_present
        expect(component.description).to be_present
        expect(component.version).to be_present
      end
    end

    context 'with invalid XCCDF file' do
      let(:invalid_file) { fixture_file_upload('test.csv', 'text/csv') }

      it 'rejects non-XML files when expecting XCCDF' do
        # This will be caught by the XML validation
        post "/projects/#{project.id}/components", params: {
          component: {
            security_requirements_guide_id: srg.id,
            file: invalid_file
          }
        }

        # Should fall back to spreadsheet import for CSV
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with malformed XML' do
      let(:bad_xml_file) do
        tempfile = Tempfile.new(['bad', '.xml'])
        tempfile.write('<invalid>xml</not-closed>')
        tempfile.rewind
        Rack::Test::UploadedFile.new(tempfile.path, 'application/xml')
      end

      it 'handles parsing errors gracefully' do
        post "/projects/#{project.id}/components", params: {
          component: {
            security_requirements_guide_id: srg.id,
            file: bad_xml_file
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['toast']['message']).to include('Error parsing XCCDF')
      end
    end
  end
end
