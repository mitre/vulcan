# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENTS:
# POST /components/detect_srg should:
# 1. Accept a file upload (CSV or XLSX)
# 2. Parse SRGID column to detect which SecurityRequirementsGuide the file targets
# 3. Return { id, srg_id, title, version } on success
# 4. Return 422 with { error } when no file provided
# 5. Return 422 with { error } when no SRG IDs found in file
# 6. Return 422 with { error } when SRG IDs don't match any known SRG
# 7. Handle ambiguous case: SRG IDs from multiple SRGs → return 422
# 8. Require authentication (redirect when not signed in)
# 9. Accept both 'SRGID' and 'SRG ID' header formats

RSpec.describe 'Components - detect_srg' do
  let_it_be(:user) { create(:user) }

  before do
    Rails.application.reload_routes!
    sign_in user
  end

  def csv_upload(content, filename: 'test.csv')
    file = Tempfile.new([filename, '.csv'])
    file.write(content)
    file.close
    Rack::Test::UploadedFile.new(file.path, 'text/csv', false)
  end

  describe 'POST /components/detect_srg' do
    context 'when not authenticated' do
      before { sign_out user }

      it 'redirects to sign in' do
        post '/components/detect_srg'
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when no file provided' do
      it 'returns 422 with error' do
        post '/components/detect_srg'
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body['error']).to eq('No file provided')
      end
    end

    context 'when file has no SRGID column' do
      it 'returns 422 with error' do
        upload = csv_upload("Name,Value\nfoo,bar\n")
        post '/components/detect_srg', params: { file: upload }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body['error']).to match(/No SRG IDs found/)
      end
    end

    context 'when file has SRGID column but no matching SRG' do
      it 'returns 422 with error' do
        upload = csv_upload("SRGID,STIGID\nSRG-NONEXISTENT-000001,XX-000001\n")
        post '/components/detect_srg', params: { file: upload }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body['error']).to match(/Could not identify/)
      end
    end

    context 'when file matches a known SRG' do
      let!(:srg) { create(:security_requirements_guide) }
      let!(:srg_rule) { create(:srg_rule, security_requirements_guide: srg) }

      it 'returns the matching SRG details' do
        upload = csv_upload("SRGID,STIGID\n#{srg_rule.version},RHEL-09-000001\n")
        post '/components/detect_srg', params: { file: upload }

        expect(response).to have_http_status(:success)
        body = response.parsed_body
        expect(body['id']).to eq(srg.id)
        expect(body['title']).to eq(srg.title)
        expect(body['version']).to eq(srg.version)
        expect(body['srg_id']).to eq(srg.srg_id)
      end
    end

    context 'when file uses aliased header "SRG ID"' do
      let!(:srg) { create(:security_requirements_guide) }
      let!(:srg_rule) { create(:srg_rule, security_requirements_guide: srg) }

      it 'normalizes the header and detects the SRG' do
        upload = csv_upload("SRG ID,STIG ID\n#{srg_rule.version},RHEL-09-000001\n")
        post '/components/detect_srg', params: { file: upload }

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['id']).to eq(srg.id)
      end
    end

    context 'when SRG IDs map to multiple different SRGs (ambiguous)' do
      let!(:srg_a) { create(:security_requirements_guide) }
      let!(:srg_b) { create(:security_requirements_guide) }
      let!(:rule_a) { create(:srg_rule, security_requirements_guide: srg_a) }
      let!(:rule_b) { create(:srg_rule, security_requirements_guide: srg_b) }

      it 'returns 422 with ambiguity error' do
        upload = csv_upload("SRGID,STIGID\n#{rule_a.version},XX-01\n#{rule_b.version},XX-02\n")
        post '/components/detect_srg', params: { file: upload }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body['error']).to match(/multiple SRGs|ambiguous/i)
      end
    end

    context 'when file is unparseable' do
      it 'returns 422 with error' do
        bad_file = Tempfile.new(['bad', '.xlsx'])
        bad_file.write('not a spreadsheet')
        bad_file.close
        upload = Rack::Test::UploadedFile.new(bad_file.path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

        post '/components/detect_srg', params: { file: upload }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body['error']).to match(/No SRG IDs found/)

        bad_file.unlink
      end
    end
  end
end
