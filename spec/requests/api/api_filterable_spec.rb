# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApiFilterable concern' do
  let_it_be(:user) { create(:user) }

  let_it_be(:project_alpha) { create(:project, name: 'Alpha Project') }
  let_it_be(:project_beta) { create(:project, name: 'Beta Project') }
  let_it_be(:project_gamma) { create(:project, name: 'Gamma Project') }

  before do
    Rails.application.reload_routes!
    sign_in user
  end

  describe 'pagination' do
    it 'returns paginated results with envelope' do
      get '/api/projects', as: :json
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to have_key('rows')
      expect(body).to have_key('pagination')
      expect(body['pagination']).to include('page', 'per_page', 'total')
    end

    it 'respects ?page= and ?per_page= params' do
      get '/api/projects', params: { per_page: 2, page: 1 }, as: :json
      body = response.parsed_body
      expect(body['rows'].size).to eq(2)
      expect(body['pagination']['page']).to eq(1)
      expect(body['pagination']['per_page']).to eq(2)
      expect(body['pagination']['total']).to be >= 3
    end

    it 'returns page 2 with correct offset' do
      get '/api/projects', params: { per_page: 2, page: 2 }, as: :json
      body = response.parsed_body
      expect(body['rows'].size).to eq(1)
      expect(body['pagination']['page']).to eq(2)
    end

    it 'clamps per_page to max 100' do
      get '/api/projects', params: { per_page: 999 }, as: :json
      body = response.parsed_body
      expect(body['pagination']['per_page']).to be <= 100
    end

    it 'returns 400 for out-of-range page' do
      get '/api/projects', params: { page: 9999 }, as: :json
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to match(/out of range/i)
    end
  end

  describe 'sorting' do
    it 'sorts by allowed field ascending' do
      get '/api/projects', params: { sort: 'name', order: 'asc' }, as: :json
      names = response.parsed_body['rows'].pluck('name')
      expect(names).to eq(names.sort)
    end

    it 'sorts by allowed field descending' do
      get '/api/projects', params: { sort: 'name', order: 'desc' }, as: :json
      names = response.parsed_body['rows'].pluck('name')
      expect(names).to eq(names.sort.reverse)
    end

    it 'ignores unknown sort fields silently' do
      get '/api/projects', params: { sort: 'nonexistent' }, as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'defaults to asc when order param is missing' do
      get '/api/projects', params: { sort: 'name' }, as: :json
      names = response.parsed_body['rows'].pluck('name')
      expect(names).to eq(names.sort)
    end

    it 'ignores invalid order values' do
      get '/api/projects', params: { sort: 'name', order: 'DROP TABLE' }, as: :json
      expect(response).to have_http_status(:ok)
      names = response.parsed_body['rows'].pluck('name')
      expect(names).to eq(names.sort)
    end
  end

  describe 'filtering via has_scope' do
    it 'filters by search query ?q=' do
      get '/api/projects', params: { q: 'Alpha' }, as: :json
      rows = response.parsed_body['rows']
      expect(rows.size).to eq(1)
      expect(rows.first['name']).to eq('Alpha Project')
    end

    it 'search is case-insensitive' do
      get '/api/projects', params: { q: 'alpha' }, as: :json
      rows = response.parsed_body['rows']
      expect(rows.size).to eq(1)
      expect(rows.first['name']).to eq('Alpha Project')
    end

    it 'search is SQL-injection safe' do
      get '/api/projects', params: { q: "'; DROP TABLE projects; --" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(Project.count).to be >= 3
    end
  end

  describe 'combined filtering + pagination + sorting' do
    before do
      create_list(:project, 5, name: 'Zulu Project')
    end

    it 'applies all three together' do
      get '/api/projects', params: { q: 'Zulu', sort: 'created_at', order: 'desc', per_page: 2, page: 1 }, as: :json
      body = response.parsed_body
      expect(body['rows'].size).to eq(2)
      expect(body['pagination']['total']).to eq(5)
      expect(body['pagination']['per_page']).to eq(2)
    end
  end

  describe 'concern generality' do
    it 'sort by created_at uses a different allowed field than name' do
      get '/api/projects', params: { sort: 'created_at', order: 'asc' }, as: :json
      expect(response).to have_http_status(:ok)
      ids = response.parsed_body['rows'].pluck('id')
      expect(ids).to eq(ids.sort)
    end

    it 'sort by updated_at uses a third allowed field' do
      get '/api/projects', params: { sort: 'updated_at', order: 'desc' }, as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'search with ILIKE wildcard characters does not break' do
      get '/api/projects', params: { q: '%_[]' }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['rows']).to be_empty
    end

    it 'search with empty query returns all records' do
      get '/api/projects', params: { q: '' }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['pagination']['total']).to be >= 3
    end

    it 'unknown has_scope params are silently ignored' do
      get '/api/projects', params: { unknown_filter: 'evil' }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['pagination']['total']).to be >= 3
    end
  end
end
