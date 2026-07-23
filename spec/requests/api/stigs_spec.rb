# frozen_string_literal: true

require 'rails_helper'

# GET /api/stigs/latest serves each STIG's highest-versioned release for
# dropdown population. Public reference data — no authentication required.
# Version ranking must be numeric (V10R1 > V2R7), never string comparison.
RSpec.describe 'Api::Stigs' do
  let_it_be(:rhel_v2) do
    create(:stig, :skip_rules,
           title: 'Red Hat Enterprise Linux 9 Security Technical Implementation Guide',
           stig_id: 'RHEL_9_STIG', version: 'V2R7',
           name: 'RHEL 9 STIG - Ver 2, Rel 7')
  end
  let_it_be(:rhel_v10) do
    create(:stig, :skip_rules,
           title: 'Red Hat Enterprise Linux 9 Security Technical Implementation Guide',
           stig_id: 'RHEL_9_STIG', version: 'V10R1',
           name: 'RHEL 9 STIG - Ver 10, Rel 1')
  end
  let_it_be(:postgres_v3) do
    create(:stig, :skip_rules,
           title: 'Crunchy Data PostgreSQL Security Technical Implementation Guide',
           stig_id: 'Crunchy_Data_PostgreSQL_STIG', version: 'V3R1',
           name: 'Crunchy Data PostgreSQL STIG - Ver 3, Rel 1')
  end

  before do
    Rails.application.reload_routes!
  end

  describe 'GET /api/stigs/latest' do
    it 'returns each STIG once, at its numerically highest version' do
      get '/api/stigs/latest'

      expect(response).to have_http_status(:ok)
      rows = response.parsed_body['rows']
      expect(rows.size).to eq(2)
      rhel = rows.find { |r| r['stig_id'] == 'RHEL_9_STIG' }
      expect(rhel['version']).to eq('V10R1')
      expect(rows.pluck('stig_id')).to contain_exactly(
        'RHEL_9_STIG', 'Crunchy_Data_PostgreSQL_STIG'
      )
    end

    it 'returns exactly id, stig_id, title, version, name per row' do
      get '/api/stigs/latest'

      row = response.parsed_body['rows'].find { |r| r['stig_id'] == 'Crunchy_Data_PostgreSQL_STIG' }
      expect(row).to eq(
        'id' => postgres_v3.id,
        'stig_id' => 'Crunchy_Data_PostgreSQL_STIG',
        'title' => 'Crunchy Data PostgreSQL Security Technical Implementation Guide',
        'version' => 'V3R1',
        'name' => 'Crunchy Data PostgreSQL STIG - Ver 3, Rel 1'
      )
    end

    it 'filters STIGs by substring, case-insensitive (?q=rhel)' do
      get '/api/stigs/latest', params: { q: 'rhel' }

      rows = response.parsed_body['rows']
      expect(rows.pluck('stig_id')).to eq(['RHEL_9_STIG'])
      expect(rows.first['version']).to eq('V10R1')
    end

    it 'matches against title as well as stig_id (?q=Crunchy)' do
      get '/api/stigs/latest', params: { q: 'Crunchy' }

      rows = response.parsed_body['rows']
      expect(rows.pluck('stig_id')).to eq(['Crunchy_Data_PostgreSQL_STIG'])
    end

    it 'returns no rows for a query matching nothing' do
      get '/api/stigs/latest', params: { q: 'zzz-no-such-query' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['rows']).to eq([])
    end

    it 'requires no authentication (public reference data)' do
      get '/api/stigs/latest'

      expect(response).to have_http_status(:ok)
    end

    it 'serializes only the dropdown identity fields — never the XML column' do
      get '/api/stigs/latest'

      all_keys = response.parsed_body['rows'].flat_map(&:keys).uniq
      expect(all_keys).to contain_exactly('id', 'stig_id', 'title', 'version', 'name')
    end
  end
end
