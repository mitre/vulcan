# frozen_string_literal: true

require 'rails_helper'

# Unit spec for the CSV generator. Tests the data shape and content-format
# contract (RFC 4180 CRLF, header order, row collapsing, email column logic).
# Transport-encoding concerns (UTF-8 BOM, Content-Type, Content-Disposition,
# auth gates, audit logging) live in the request spec — see
# spec/requests/components_disposition_matrix_export_spec.rb.
RSpec.describe DispositionMatrixExport do
  let_it_be(:project)   { create(:project) }
  let_it_be(:srg)       { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg) }
  let_it_be(:author)    { create(:user, name: 'Aaron Lippold') }
  let_it_be(:commenter) { create(:user, name: 'Sarah K', email: 'sarah@example.com') }

  before do
    Membership.find_or_create_by!(user: author, membership: project) { |m| m.role = 'author' }
    Membership.find_or_create_by!(user: commenter, membership: project) { |m| m.role = 'viewer' }
  end

  let(:rule) { component.rules.first }

  let!(:c1) do
    Review.create!(rule: rule, user: commenter, action: 'comment',
                   section: 'check_content', comment: 'check text issue',
                   triage_status: 'concur_with_comment',
                   triage_set_by: author, triage_set_at: 1.day.ago,
                   adjudicated_at: 12.hours.ago, adjudicated_by: author)
  end
  let!(:reply) do
    Review.create!(rule: rule, user: author, action: 'comment',
                   responding_to_review_id: c1.id,
                   comment: 'will fix in next revision',
                   triage_status: 'pending')
  end

  describe '.generate' do
    subject(:csv) { described_class.generate(component: component) }

    it 'uses CRLF row separators per RFC 4180' do
      expect(csv).to include("\r\n")
      # No bare LF that is not preceded by CR
      expect(csv.scan(/(?<!\r)\n/)).to be_empty
    end

    it 'does NOT include a UTF-8 BOM (BOM is a transport-encoding concern)' do
      expect(csv.bytes.first(3)).not_to eq([0xEF, 0xBB, 0xBF])
    end

    it 'starts with the locked header row' do
      header_row = csv.lines.first.chomp
      expect(header_row).to eq(described_class::BASE_HEADERS.join(','))
    end

    it 'returns one row per top-level comment with replies collapsed into Triager Response' do
      parsed = CSV.parse(csv, headers: true)
      expect(parsed.length).to eq(1)
      row = parsed.first
      expect(row['Comment ID']).to eq(c1.id.to_s)
      expect(row['Rule']).to eq("#{component.prefix}-#{rule.rule_id}")
      expect(row['Triager Response']).to include('will fix')
      expect(row['Triage Status']).to eq('concur_with_comment')
      expect(row['Adjudicated']).to eq('true')
    end

    it 'filters by triage_status when provided' do
      Review.create!(rule: rule, user: commenter, action: 'comment',
                     comment: 'pending one', triage_status: 'pending')
      filtered = described_class.generate(component: component, triage_status_filter: 'pending')
      parsed = CSV.parse(filtered, headers: true)
      expect(parsed.length).to eq(1)
      expect(parsed.first['Triage Status']).to eq('pending')
    end

    context 'when include_email is false (default)' do
      it 'omits the Commenter Email column entirely' do
        expect(csv).not_to include('Commenter Email')
        expect(csv).not_to include('sarah@example.com')
      end
    end

    context 'when include_email is true' do
      subject(:csv) { described_class.generate(component: component, include_email: true) }

      it 'inserts Commenter Email column adjacent to Commenter Name' do
        parsed = CSV.parse(csv, headers: true)
        expect(parsed.headers).to include('Commenter Email')
        expect(parsed.first['Commenter Email']).to eq('sarah@example.com')
      end
    end
  end

  # generate_file wraps the pure CSV string in an Export::Result struct so
  # the single-component HTTP path and the Working Copy CSV piggyback path
  # can share a single source of truth for filename pattern and content-type.
  describe '.generate_file' do
    subject(:result) { described_class.generate_file(component: component) }

    it 'returns an Export::Result' do
      expect(result).to be_a(Export::Result)
    end

    it 'sets data to the same CSV bytes generate would emit' do
      expect(result.data).to eq(described_class.generate(component: component))
    end

    it 'sets a per-component filename including project + component prefix + date' do
      expect(result.filename).to include(component.project.name)
      expect(result.filename).to include(component.prefix)
      expect(result.filename).to include('disposition-matrix')
      expect(result.filename).to end_with('.csv')
    end

    it 'sets content_type to text/csv' do
      expect(result.content_type).to eq('text/csv')
    end

    it 'forwards triage_status_filter and include_email through' do
      file = described_class.generate_file(component: component, include_email: true)
      expect(file.data).to include('Commenter Email')
    end
  end

  # rows_and_headers exposes the same row structure that generate(component:)
  # serialises to CSV — but as a Ruby array-of-arrays rather than a CSV string.
  # Lets the Excel multi-sheet pipeline consume disposition data directly as
  # a sheet without parsing CSV bytes back out.
  describe '.rows_and_headers' do
    subject(:result) { described_class.rows_and_headers(component: component) }

    it 'returns a hash with :headers and :rows keys' do
      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly(:headers, :rows)
    end

    it 'headers match the locked BASE_HEADERS when include_email is false' do
      expect(result[:headers]).to eq(described_class::BASE_HEADERS)
    end

    it 'rows are arrays of cell values, one per top-level comment' do
      expect(result[:rows]).to be_an(Array)
      expect(result[:rows].length).to eq(1)
      first_row = result[:rows].first
      expect(first_row).to be_an(Array)
      expect(first_row.length).to eq(described_class::BASE_HEADERS.length)
    end

    it 'cell values match the same rows that generate(component:) emits' do
      parsed_csv = CSV.parse(described_class.generate(component: component), headers: true)
      csv_first_row = parsed_csv.first.fields

      helper_first_row = result[:rows].first.map { |v| v&.to_s }
      csv_normalised = csv_first_row.map(&:presence)
      helper_normalised = helper_first_row.map(&:presence)
      expect(helper_normalised).to eq(csv_normalised)
    end

    it 'inserts the Commenter Email column when include_email is true' do
      out = described_class.rows_and_headers(component: component, include_email: true)
      expect(out[:headers]).to include('Commenter Email')
      email_index = out[:headers].index('Commenter Email')
      expect(out[:rows].first[email_index]).to eq('sarah@example.com')
    end

    it 'forwards triage_status_filter through' do
      Review.create!(rule: rule, user: commenter, action: 'comment',
                     comment: 'pending one', triage_status: 'pending')
      filtered = described_class.rows_and_headers(component: component, triage_status_filter: 'pending')
      expect(filtered[:rows].length).to eq(1)
      status_index = filtered[:headers].index('Triage Status')
      expect(filtered[:rows].first[status_index]).to eq('pending')
    end
  end
end
