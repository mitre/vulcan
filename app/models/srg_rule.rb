# frozen_string_literal: true

# SrgRules are rules which belong to an SRG (Security Requirements Guide)
# SRGs are baseline security requirements published by DoD/DISA
class SrgRule < BaseRule
  include PgSearch::Model

  amoeba do
    # This is used to clone SRGRules to Rules, easing the import process
    set type: Rule
    through :become_rule
  end

  belongs_to :security_requirements_guide

  # Full-text search scope for SRG rule content
  pg_search_scope :search_content,
                  against: {
                    title: 'A',           # Highest weight
                    fixtext: 'B',         # High weight
                    version: 'C'          # Medium weight
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

  def self.from_mapping(rule_mapping, srg_id)
    rule = super(self, rule_mapping)
    rule.security_requirements_guide_id = srg_id

    rule
  end

  private

  def become_rule
    dup.becomes(Rule)
  end
end
