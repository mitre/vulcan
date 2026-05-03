# frozen_string_literal: true

require 'csv'

# DISA disposition matrix CSV export — required deliverable for
# public-comment review windows. One row per top-level comment, with reply
# threads collapsed into the Triager Response column. DISA-vocab cell values
# (concur / non_concur / etc.) so the file is consumed as raw data.
#
# Email column is opt-in via `include_email: true` and only set by the
# controller when the requesting user satisfies admin-tier authorization;
# viewer/author tiers cannot opt in.
module DispositionMatrixExport
  BASE_HEADERS = [
    'Comment ID', 'Rule', 'SRG ID', 'Section',
    'Commenter Name', 'Comment', 'Posted',
    'Triage Status', 'Triaged By', 'Triaged At', 'Triager Response',
    'Adjudicated', 'Adjudicated By', 'Adjudicated At', 'Duplicate Of'
  ].freeze

  # Returns CRLF-separated UTF-8 CSV per RFC 4180. No BOM — RFC 4180 does not
  # mention BOM, and the UK Government tabular data standard explicitly
  # recommends removing BOM before publishing. Excel-on-Windows users open
  # via Data → Get Data → From Text/CSV (Power Query), which is Microsoft's
  # own recommended path and handles UTF-8 reliably without a BOM marker.
  def self.generate(component:, triage_status_filter: nil, include_email: false)
    data = rows_and_headers(
      component: component,
      triage_status_filter: triage_status_filter,
      include_email: include_email
    )
    CSV.generate(row_sep: "\r\n") do |out|
      out << data[:headers]
      data[:rows].each { |row| out << row }
    end
  end

  # Returns the disposition matrix as { headers: [...], rows: [[...], ...] }
  # — the same shape Vulcan's Excel multi-sheet pipeline expects. Letting
  # the Excel pipeline consume disposition data directly avoids round-tripping
  # through CSV serialization just to parse it back out into a sheet.
  def self.rows_and_headers(component:, triage_status_filter: nil, include_email: false)
    reviews = top_level_reviews(component, triage_status_filter)
    replies_by_parent = load_replies(reviews.map(&:id))
    {
      headers: build_headers(include_email),
      rows: reviews.map { |r| build_row(r, component, replies_by_parent[r.id], include_email: include_email) }
    }
  end

  # True iff the component has at least one top-level review (a row that
  # would appear in the disposition matrix). Used by the Working Copy
  # CSV/Excel piggyback paths to decide whether to attach the disposition
  # artifact for this component. Matches top_level_reviews semantics.
  def self.records_exist?(component)
    Review.top_level_comments
          .joins(:rule)
          .merge(Rule.where(component_id: component.id))
          .exists?
  end

  # Wraps generate(component:) in an Export::Result so the single-component
  # HTTP path AND the Working Copy CSV piggyback path share one source of
  # truth for filename pattern and content-type. Filename matches the
  # existing convention: "<project>-<prefix>-disposition-matrix-<YYYY-MM-DD>.csv".
  def self.generate_file(component:, **)
    csv = generate(component: component, **)
    filename = "#{component.project.name}-#{component.prefix}-disposition-matrix-#{Date.current}.csv"
    Export::Result.new(data: csv, filename: filename, content_type: 'text/csv')
  end

  def self.build_headers(include_email)
    return BASE_HEADERS unless include_email

    BASE_HEADERS.dup.insert(BASE_HEADERS.index('Comment'), 'Commenter Email')
  end

  def self.build_row(review, component, replies, include_email:)
    # Defang each reply individually before joining so a malicious reply
    # is neutralised even when concatenated into the Triager Response cell.
    responses = (replies || [])
                .sort_by(&:created_at)
                .map { |x| defang(x.comment.to_s.strip) }
                .compact_blank
                .join("\n---\n")

    row = [
      review.id,
      "#{component.prefix}-#{review.rule.rule_id}",
      review.rule.version,
      review.section.to_s,
      defang(review.user&.name)
    ]
    row << defang(review.user&.email) if include_email
    row += [
      defang(review.comment),
      review.created_at.iso8601,
      review.triage_status,
      defang(attribution_label(review, :triage_set_by)),
      review.triage_set_at&.iso8601,
      responses,
      review.adjudicated_at.present?,
      defang(attribution_label(review, :adjudicated_by)),
      review.adjudicated_at&.iso8601,
      review.duplicate_of_review_id
    ]
    row
  end

  # PR-717 review remediation .8 — prefer the resolved User's name; fall
  # back to the imported_email / imported_name when the FK is nil but the
  # archive carried original attribution forward (cross-instance restore
  # where the User didn't exist on the target). DISA reviewers still see
  # WHO triaged in the deliverable, with an explicit "imported, no account"
  # annotation so the trail is unambiguous.
  def self.attribution_label(review, role)
    user = review.public_send(role)
    return user.name if user

    imported_name = review.public_send(:"#{role}_imported_name")
    imported_email = review.public_send(:"#{role}_imported_email")
    return nil if imported_name.blank? && imported_email.blank?

    "#{imported_name} (imported, no account: #{imported_email})"
  end

  # OWASP CSV Injection / formula injection. When a reviewer opens the
  # disposition matrix in Excel/Sheets, a cell whose value starts with =, +,
  # -, @, tab (\t) or CR (\r) is interpreted as a formula. Prefix a single
  # quote so the cell is rendered literally instead. Apply only to untrusted
  # commenter content (review.comment, replies, user.name, user.email);
  # numeric IDs / ISO timestamps / enum statuses are non-string and trusted.
  FORMULA_TRIGGER = /\A[=+\-@\t\r]/
  private_constant :FORMULA_TRIGGER

  def self.defang(value)
    return value if value.nil?

    s = value.to_s
    s.match?(FORMULA_TRIGGER) ? "'#{s}" : s
  end

  def self.top_level_reviews(component, status_filter)
    scope = Review.top_level_comments
                  .joins(:rule)
                  .merge(Rule.where(component_id: component.id))
                  .preload(:user, :triage_set_by, :adjudicated_by, :rule)
                  .order(created_at: :asc)
    scope = scope.where(triage_status: status_filter) if status_filter.present? && status_filter != 'all'
    scope.to_a
  end

  def self.load_replies(parent_ids)
    return {} if parent_ids.empty?

    Review.where(responding_to_review_id: parent_ids)
          .preload(:user)
          .group_by(&:responding_to_review_id)
  end
end
