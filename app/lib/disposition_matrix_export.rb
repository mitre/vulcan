# frozen_string_literal: true

require 'csv'

# DISA disposition matrix CSV export — federal-compliance deliverable for
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
    reviews = top_level_reviews(component, triage_status_filter)
    replies_by_parent = load_replies(reviews.map(&:id))
    headers = build_headers(include_email)

    CSV.generate(row_sep: "\r\n") do |out|
      out << headers
      reviews.each do |r|
        out << build_row(r, component, replies_by_parent[r.id], include_email: include_email)
      end
    end
  end

  def self.build_headers(include_email)
    return BASE_HEADERS unless include_email

    BASE_HEADERS.dup.insert(BASE_HEADERS.index('Comment'), 'Commenter Email')
  end

  def self.build_row(review, component, replies, include_email:)
    responses = (replies || [])
                .sort_by(&:created_at)
                .map { |x| x.comment.to_s.strip }
                .compact_blank
                .join("\n---\n")

    row = [
      review.id,
      "#{component.prefix}-#{review.rule.rule_id}",
      review.rule.version,
      review.section.to_s,
      review.user&.name
    ]
    row << review.user&.email if include_email
    row += [
      review.comment,
      review.created_at.iso8601,
      review.triage_status,
      review.triage_set_by&.name,
      review.triage_set_at&.iso8601,
      responses,
      review.adjudicated_at.present?,
      review.adjudicated_by&.name,
      review.adjudicated_at&.iso8601,
      review.duplicate_of_review_id
    ]
    row
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
