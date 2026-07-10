# frozen_string_literal: true

require 'rails_helper'

# GET /api/srgs/latest serves the highest-versioned SRG per family for
# dropdown population. Public reference data — no authentication required.
# Version ranking must be numeric (V10R1 > V4R4), never string comparison.
RSpec.describe 'Api::Srgs' do
  let_it_be(:gpos_v3) do
    create(:security_requirements_guide,
           title: 'General Purpose Operating System Security Requirements Guide',
           srg_id: 'General_Purpose_Operating_System', version: 'V3R3',
           name: 'General Purpose Operating System - Ver 3, Rel 3')
  end
  let_it_be(:gpos_v10) do
    create(:security_requirements_guide,
           title: 'General Purpose Operating System Security Requirements Guide',
           srg_id: 'General_Purpose_Operating_System', version: 'V10R1',
           name: 'General Purpose Operating System - Ver 10, Rel 1')
  end
  let_it_be(:web_v4) do
    create(:security_requirements_guide,
           title: 'Web Server Security Requirements Guide',
           srg_id: 'Web_Server_SRG', version: 'V4R4',
           name: 'Web Server SRG - Ver 4, Rel 4')
  end

  before do
    Rails.application.reload_routes!
  end

  describe 'GET /api/srgs/latest' do
    it 'returns one SRG per family with the numerically highest version' do
      get '/api/srgs/latest'

      expect(response).to have_http_status(:ok)
      rows = response.parsed_body['rows']
      expect(rows.size).to eq(2)
      gpos = rows.find { |r| r['srg_id'] == 'General_Purpose_Operating_System' }
      expect(gpos['version']).to eq('V10R1')
      expect(rows.pluck('srg_id')).to contain_exactly(
        'General_Purpose_Operating_System', 'Web_Server_SRG'
      )
    end

    it 'returns exactly id, srg_id, title, version, name per row' do
      get '/api/srgs/latest'

      row = response.parsed_body['rows'].find { |r| r['srg_id'] == 'Web_Server_SRG' }
      expect(row).to eq(
        'id' => web_v4.id,
        'srg_id' => 'Web_Server_SRG',
        'title' => 'Web Server Security Requirements Guide',
        'version' => 'V4R4',
        'name' => 'Web Server SRG - Ver 4, Rel 4'
      )
    end

    it 'filters families by substring, case-insensitive (?q=web_server)' do
      get '/api/srgs/latest', params: { q: 'web_server' }

      rows = response.parsed_body['rows']
      expect(rows.pluck('srg_id')).to eq(['Web_Server_SRG'])
    end

    it 'expands the GPOS abbreviation to the General_Purpose_Operating_System family (?q=GPOS)' do
      get '/api/srgs/latest', params: { q: 'GPOS' }

      rows = response.parsed_body['rows']
      expect(rows.pluck('srg_id')).to eq(['General_Purpose_Operating_System'])
      expect(rows.first['version']).to eq('V10R1')
    end

    it 'returns no rows for a query matching nothing' do
      get '/api/srgs/latest', params: { q: 'zzz-no-such-family' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['rows']).to eq([])
    end

    it 'requires no authentication (public reference data)' do
      get '/api/srgs/latest'

      expect(response).to have_http_status(:ok)
    end

    it 'serializes only the dropdown identity fields — never the XML column' do
      get '/api/srgs/latest'

      all_keys = response.parsed_body['rows'].flat_map(&:keys).uniq
      expect(all_keys).to contain_exactly('id', 'srg_id', 'title', 'version', 'name')
    end
  end
end
