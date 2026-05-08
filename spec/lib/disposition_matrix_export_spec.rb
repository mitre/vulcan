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
                   comment: 'will fix in next revision')
  end

  describe 'reactions in Thread Replies cell' do
    let_it_be(:reactor) do
      u = create(:user, name: 'Maya Reactor')
      Membership.find_or_create_by!(user: u, membership: project) { |m| m.role = 'viewer' }
      u
    end

    it 'appends a reaction on the parent comment as a [name · ts] reacted label entry' do
      Reaction.create!(review: c1, user: reactor, kind: 'up', created_at: 30.minutes.ago)
      out = CSV.parse(described_class.generate(component: component), headers: true)
      cell = out.find { |r| r['Comment ID'] == c1.id.to_s }['Thread Replies']
      expect(cell).to include('Maya Reactor')
      expect(cell).to include('reacted thumbs-up')
    end

    it 'includes reactions on REPLIES too (Decision 7)' do
      Reaction.create!(review: reply, user: reactor, kind: 'down', created_at: 5.minutes.ago)
      out = CSV.parse(described_class.generate(component: component), headers: true)
      cell = out.find { |r| r['Comment ID'] == c1.id.to_s }['Thread Replies']
      expect(cell).to include('reacted thumbs-down')
    end

    it 'orders entries chronologically (created_at ascending)' do
      r1 = Reaction.create!(review: c1, user: reactor, kind: 'up', created_at: 2.hours.ago)
      r2 = Reaction.create!(review: c1, user: author, kind: 'down', created_at: 1.hour.ago)
      out = CSV.parse(described_class.generate(component: component), headers: true)
      cell = out.find { |r| r['Comment ID'] == c1.id.to_s }['Thread Replies']
      idx_r1 = cell.index(r1.created_at.iso8601)
      idx_r2 = cell.index(r2.created_at.iso8601)
      expect(idx_r1).to be < idx_r2
    end

    it 'reaction_author_label returns (unknown) when the user association is nil' do
      orphan = Reaction.new(kind: 'up')
      allow(orphan).to receive(:user).and_return(nil)
      expect(described_class.reaction_author_label(orphan)).to eq('(unknown)')
    end
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

    it 'returns one row per top-level comment with replies collapsed into Thread Replies' do
      parsed = CSV.parse(csv, headers: true)
      expect(parsed.length).to eq(1)
      row = parsed.first
      expect(row['Comment ID']).to eq(c1.id.to_s)
      expect(row['Rule']).to eq("#{component.prefix}-#{rule.rule_id}")
      expect(row['Thread Replies']).to include('will fix')
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
  # Formula injection defang.
  # Untrusted commenter content (review.comment, replies, user.name, user.email)
  # MUST be defanged before landing in CSV/Excel cells. Reviewers open the
  # disposition matrix in Excel/Sheets, where a leading `=`/`+`/`-`/`@`/tab/CR
  # turns the cell into a formula. OWASP CSV Injection.
  describe 'formula-injection defang' do
    let!(:evil_user) do
      u = create(:user, name: 'placeholder')
      Membership.find_or_create_by!(user: u, membership: project) { |m| m.role = 'viewer' }
      # Devise blocks formula-trigger characters at validation; bypass with
      # update_columns since the goal is to test export defang, not to test
      # that such records can be saved through normal means.
      u.update_columns(name: '=cmd|attacker', email: '@evil@example.com')
      u
    end
    let!(:evil_review) do
      Review.create!(
        rule: component.rules.second,
        user: evil_user,
        action: 'comment',
        comment: '=HYPERLINK("http://evil/x", "Click me")',
        triage_status: 'pending'
      )
    end
    let(:rows) { CSV.parse(described_class.generate(component: component, include_email: true), headers: true) }
    let(:evil_row) { rows.find { |r| r['Comment ID'] == evil_review.id.to_s } }

    it 'prefixes a single-quote on a comment that starts with =' do
      expect(evil_row['Comment']).to start_with("'=")
      expect(evil_row['Comment']).to eq(%q('=HYPERLINK("http://evil/x", "Click me")))
    end

    it 'defangs a commenter name that starts with =' do
      expect(evil_row['Commenter Name']).to start_with("'=")
      expect(evil_row['Commenter Name']).to eq("'=cmd|attacker")
    end

    it 'defangs a commenter email that starts with @' do
      expect(evil_row['Commenter Email']).to eq("'@evil@example.com")
    end

    it 'defangs comments starting with each Excel formula trigger character' do
      %w[+ - @].each do |char|
        Review.create!(
          rule: component.rules.first, user: commenter, action: 'comment',
          comment: "#{char}danger", triage_status: 'pending'
        )
      end
      Review.create!(
        rule: component.rules.first, user: commenter, action: 'comment',
        comment: "\tTAB-leading", triage_status: 'pending'
      )
      Review.create!(
        rule: component.rules.first, user: commenter, action: 'comment',
        comment: "\rCR-leading", triage_status: 'pending'
      )
      out = CSV.parse(described_class.generate(component: component), headers: true)
      # rubocop:disable Rails/Pluck -- CSV::Table rows are not ActiveRecord
      comments = out.map { |r| r['Comment'] }
      # rubocop:enable Rails/Pluck
      expect(comments).to include("'+danger", "'-danger", "'@danger")
      expect(comments).to include(start_with("'\t"))
      expect(comments).to include(start_with("'\r"))
    end

    it 'leaves legitimate text content unchanged (no leading defang character)' do
      legit = Review.create!(
        rule: component.rules.first, user: commenter, action: 'comment',
        comment: 'Plain English with no formulas — totally fine.',
        triage_status: 'pending'
      )
      out = CSV.parse(described_class.generate(component: component), headers: true)
      legit_row = out.find { |r| r['Comment ID'] == legit.id.to_s }
      expect(legit_row['Comment']).to eq('Plain English with no formulas — totally fine.')
    end

    it 'does NOT defang non-string cells (id, timestamps, enum statuses, booleans)' do
      expect(evil_row['Comment ID']).to eq(evil_review.id.to_s)
      expect(evil_row['Comment ID']).not_to start_with("'")
      expect(evil_row['Triage Status']).to eq('pending')
      expect(evil_row['Triage Status']).not_to start_with("'")
      expect(evil_row['Posted']).to match(/\A\d{4}-\d{2}-\d{2}T/)
      expect(evil_row['Posted']).not_to start_with("'")
    end

    it 'rows_and_headers (Excel sheet path) returns the same defanged values' do
      out = described_class.rows_and_headers(component: component, include_email: true)
      comment_idx = out[:headers].index('Comment')
      name_idx = out[:headers].index('Commenter Name')
      email_idx = out[:headers].index('Commenter Email')
      evil_arr = out[:rows].find { |r| r[0] == evil_review.id }
      expect(evil_arr[comment_idx]).to start_with("'=")
      expect(evil_arr[name_idx]).to start_with("'=")
      expect(evil_arr[email_idx]).to start_with("'@")
    end

    it 'defangs each individual reply within the joined Thread Replies cell' do
      parent = Review.create!(rule: component.rules.first, user: commenter,
                              action: 'comment', comment: 'parent question',
                              triage_status: 'pending')
      Review.create!(rule: component.rules.first, user: author,
                     action: 'comment', responding_to_review_id: parent.id,
                     comment: '=DANGER_REPLY')
      Review.create!(rule: component.rules.first, user: author,
                     action: 'comment', responding_to_review_id: parent.id,
                     comment: 'normal reply')
      out = CSV.parse(described_class.generate(component: component), headers: true)
      parent_row = out.find { |r| r['Comment ID'] == parent.id.to_s }
      expect(parent_row['Thread Replies']).to include("'=DANGER_REPLY")
      expect(parent_row['Thread Replies']).to include('normal reply')
    end
  end

  # when triage_set_by_id (or adjudicated_by_id)
  # is nil but triage_set_by_imported_email/name are populated (cross-instance
  # restore where the user didn't exist on the target), the disposition CSV
  # falls back to the imported_* fields so DISA reviewers still see WHO
  # triaged in the deliverable. Annotation marks the row as imported.
  describe 'imported-attribution fallback in Triaged By / Adjudicated By cells' do
    let!(:imported_review) do
      Review.create!(rule: rule, user: commenter, action: 'comment',
                     comment: 'cross-instance review',
                     triage_status: 'concur',
                     triage_set_at: 1.day.ago,
                     adjudicated_at: 12.hours.ago,
                     triage_set_by_imported_email: 'alice@example.com',
                     triage_set_by_imported_name: 'Alice External',
                     adjudicated_by_imported_email: 'bob@example.com',
                     adjudicated_by_imported_name: 'Bob External')
    end
    let(:rows) { CSV.parse(described_class.generate(component: component), headers: true) }
    let(:imported_row) { rows.find { |r| r['Comment ID'] == imported_review.id.to_s } }

    it 'falls back to imported name + email annotation in the Triaged By cell' do
      expect(imported_row['Triaged By']).to eq('Alice External (imported, no account: alice@example.com)')
    end

    it 'falls back to imported name + email annotation in the Adjudicated By cell' do
      expect(imported_row['Adjudicated By']).to eq('Bob External (imported, no account: bob@example.com)')
    end

    it 'uses the resolved User name when triage_set_by_id is present' do
      author_review = Review.create!(rule: rule, user: commenter, action: 'comment',
                                     comment: 'normal triaged review',
                                     triage_status: 'concur',
                                     triage_set_by: author, triage_set_at: 1.day.ago,
                                     adjudicated_at: 12.hours.ago, adjudicated_by: author)
      out = CSV.parse(described_class.generate(component: component), headers: true)
      row = out.find { |r| r['Comment ID'] == author_review.id.to_s }
      expect(row['Triaged By']).to eq('Aaron Lippold')
      expect(row['Adjudicated By']).to eq('Aaron Lippold')
    end

    it 'leaves the cell blank when both FK and imported_* are nil (legacy)' do
      legacy = Review.create!(rule: rule, user: commenter, action: 'comment',
                              comment: 'legacy untriaged', triage_status: 'pending')
      out = CSV.parse(described_class.generate(component: component), headers: true)
      row = out.find { |r| r['Comment ID'] == legacy.id.to_s }
      expect(row['Triaged By']).to be_blank
      expect(row['Adjudicated By']).to be_blank
    end
  end

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

  describe '.generate_for_project' do
    let!(:second_component) do
      c = create(:component, project: project, based_on: srg, prefix: 'XYZW-99', name: 'Second component')
      Review.create!(rule: c.rules.first, user: commenter, action: 'comment',
                     comment: 'on second component', triage_status: 'pending')
      c
    end

    it 'unions rows from every component with a leading Component column' do
      csv = described_class.generate_for_project(project: project)
      out = CSV.parse(csv, headers: true)
      expect(out.headers.first).to eq('Component')
      components_in_output = out.pluck('Component').uniq
      expect(components_in_output.size).to eq(2)
      expect(components_in_output).to include(a_string_matching(/#{component.prefix} — /))
      expect(components_in_output).to include(a_string_matching(/XYZW-99 — Second component/))
    end

    it 'preserves row count = sum of per-component row counts' do
      per_component_rows = project.components.sum do |c|
        described_class.rows_and_headers(component: c)[:rows].length
      end
      project_rows = CSV.parse(described_class.generate_for_project(project: project), headers: true)
      expect(project_rows.length).to eq(per_component_rows)
    end

    it 'returns headers-only CSV when project has no components' do
      empty_project = create(:project)
      csv = described_class.generate_for_project(project: empty_project)
      out = CSV.parse(csv, headers: true)
      expect(out.headers.first).to eq('Component')
      expect(out.length).to eq(0)
    end

    it 'forwards triage_status_filter across all components' do
      csv = described_class.generate_for_project(project: project, triage_status_filter: 'pending')
      out = CSV.parse(csv, headers: true)
      expect(out.pluck('Triage Status').uniq).to eq(['pending'])
    end

    it 'opt-in include_email adds Commenter Email column' do
      csv = described_class.generate_for_project(project: project, include_email: true)
      out = CSV.parse(csv, headers: true)
      expect(out.headers).to include('Commenter Email')
    end
  end
end
