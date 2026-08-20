# frozen_string_literal: true

# Query filtering for benchmark reference listings (SRGs, STIGs).
#
# Expands the raw query through SearchQueryService (normalization +
# abbreviation expansion, e.g. GPOS -> General Purpose Operating System)
# so dropdown filtering matches the same terms as global search.
#
# Including models must define `search_columns` — the whitelist of columns
# the ILIKE conditions are built from (column names are code-owned literals,
# user input is parameterized).
module BenchmarkSearchable
  extend ActiveSupport::Concern

  class_methods do
    def search(query)
      terms = SearchQueryService.transform(query)[:ilike_terms]
      return none if terms.empty?

      conditions = terms.map do
        "(#{search_columns.map { |col| "#{col} ILIKE ?" }.join(' OR ')})"
      end.join(' OR ')
      values = terms.flat_map do |term|
        Array.new(search_columns.size, "%#{sanitize_sql_like(term)}%")
      end
      where(conditions, *values)
    end
  end
end
