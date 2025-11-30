# frozen_string_literal: true

# StigRules are rules which belong to a STIG (published security guidance)
# STIGs are "released components" published by DoD/DISA
class StigRule < BaseRule
  include PgSearch::Model

  belongs_to :stig

  # Full-text search scope for STIG rule content
  pg_search_scope :search_content,
                  against: {
                    title: 'A',           # Highest weight
                    fixtext: 'B',         # High weight
                    version: 'C'          # Medium weight (e.g., SV-230221r858734_rule)
                  },
                  associated_against: {
                    checks: :content,
                    disa_rule_descriptions: %i[vuln_discussion mitigations]
                  },
                  using: {
                    tsearch: {
                      prefix: true,
                      dictionary: 'english',
                      any_word: false
                    },
                    trigram: {
                      threshold: 0.2
                    }
                  },
                  ranked_by: ':tsearch + (0.5 * :trigram)'

  ##
  # Phrase search using PostgreSQL's websearch_to_tsquery
  # Supports Google-like syntax: "exact phrase", -excluded, OR
  #
  scope :search_phrase, lambda { |query|
    return none if query.blank?

    # Use table_name (base_rules) instead of hardcoded name due to STI
    tsvector_sql = <<~SQL.squish
      setweight(to_tsvector('english', coalesce(#{table_name}.title, '')), 'A') ||
      setweight(to_tsvector('english', coalesce(#{table_name}.fixtext, '')), 'B') ||
      setweight(to_tsvector('english', coalesce(#{table_name}.version, '')), 'C')
    SQL

    where("(#{tsvector_sql}) @@ websearch_to_tsquery('english', ?)", query)
      .order(Arel.sql("ts_rank((#{tsvector_sql}), websearch_to_tsquery('english', #{connection.quote(query)})) DESC"))
  }

  def self.from_mapping(group_mapping, stig_id)
    rule = super(self, group_mapping.rule.first)
    rule.stig_id = stig_id
    rule.srg_id = group_mapping.title.first
    rule.vuln_id = group_mapping.id
    rule
  end
end
