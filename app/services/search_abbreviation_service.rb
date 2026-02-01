# frozen_string_literal: true

##
# Service for managing search abbreviation expansion
#
# Merges core abbreviations (from config file) with user abbreviations (from database).
# User abbreviations take precedence over core when there's a conflict.
#
# Usage:
#   SearchAbbreviationService.expand_query('RHEL')
#   # => ['RHEL', 'Red Hat Enterprise Linux']
#
#   SearchAbbreviationService.all
#   # => { 'RHEL' => 'Red Hat Enterprise Linux', ... }
#
class SearchAbbreviationService
  CACHE_KEY = 'search_abbreviations_merged'
  CACHE_TTL = 1.hour

  class << self
    ##
    # Get all abbreviations (core + user, merged)
    # User abbreviations override core when keys match
    #
    # @return [Hash] abbreviation => expansion
    #
    def all
      Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
        core_abbreviations.merge(user_abbreviations)
      end
    end

    ##
    # Expand a query with abbreviation matches
    # Returns array of search terms including original and expansions
    #
    # @param query [String] the search query
    # @return [Array<String>] expanded search terms
    #
    def expand_query(query)
      abbreviations = all
      expanded_terms = [query]

      # Check each word in query against abbreviations (case-insensitive)
      query.split(/\s+/).each do |word|
        expansion = abbreviations[word.upcase] || abbreviations[word]
        expanded_terms << expansion if expansion
      end

      expanded_terms.uniq
    end

    ##
    # Clear the cached abbreviations
    # Called automatically when user abbreviations change
    #
    def clear_cache!
      Rails.cache.delete(CACHE_KEY)
    end

    ##
    # Get core abbreviations only (for admin display)
    #
    # @return [Hash] abbreviation => expansion
    #
    def core_only
      core_abbreviations
    end

    private

    ##
    # Load core abbreviations from config file
    #
    def core_abbreviations
      config_path = Rails.root.join('config', 'search_abbreviations.yml')
      return {} unless File.exist?(config_path)

      config = YAML.load_file(config_path)
      config['abbreviations'] || {}
    rescue StandardError => e
      Rails.logger.error("Failed to load core abbreviations: #{e.message}")
      {}
    end

    ##
    # Load active user abbreviations from database
    #
    def user_abbreviations
      SearchAbbreviation.active.pluck(:abbreviation, :expansion).to_h
    rescue StandardError => e
      Rails.logger.error("Failed to load user abbreviations: #{e.message}")
      {}
    end
  end
end
