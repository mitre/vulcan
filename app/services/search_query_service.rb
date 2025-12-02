# frozen_string_literal: true

##
# Service for transforming raw search queries into search-ready terms
#
# Centralizes all query transformation logic:
# - Phrase search ("exact phrase" → phrase search with FOLLOWED BY operator)
# - Normalization (PascalCase, letter-number boundaries, separators)
# - Abbreviation expansion (RHEL → Red Hat Enterprise Linux)
# - Filename expansion (sshd.conf → sshd conf for pg_search)
#
# Usage:
#   result = SearchQueryService.transform('sshd.conf')
#   # => {
#   #      ilike_terms: ['sshd.conf', 'sshd conf'],
#   #      pg_search_term: 'sshd conf',
#   #      normalized: 'sshd.conf',
#   #      has_phrases: false
#   #    }
#
#   result = SearchQueryService.transform('"I want this"')
#   # => {
#   #      ilike_terms: ['I want this'],
#   #      pg_search_term: 'I <-> want <-> this',
#   #      normalized: '"I want this"',
#   #      has_phrases: true
#   #    }
#
#   result = SearchQueryService.transform('RHEL9')
#   # => {
#   #      ilike_terms: ['RHEL 9', 'Red Hat Enterprise Linux'],
#   #      pg_search_term: 'RHEL 9',
#   #      normalized: 'RHEL 9',
#   #      has_phrases: false
#   #    }
#
class SearchQueryService
  # Common config/text file extensions for filename detection
  FILENAME_EXTENSIONS = %w[
    conf cfg config ini yaml yml json xml properties
    txt log sh bash zsh
    rb py pl js ts
    c cpp h hpp
    java class jar
    sql
  ].freeze

  class << self
    ##
    # Main entry point - transforms raw query into search-ready terms
    #
    # @param raw_query [String] the user's search input
    # @return [Hash] with keys :ilike_terms, :pg_search_term, :normalized, :has_phrases
    #
    def transform(raw_query)
      query = raw_query.to_s.strip
      return empty_result if query.length < 2

      # Step 0: Check for phrase search (quoted strings)
      phrase_result = extract_phrases(query)

      if phrase_result[:has_phrases]
        # Phrase search mode - use exact matching
        return build_phrase_result(phrase_result)
      end

      # Regular search mode - continue with existing logic

      # Step 1: Expand abbreviations BEFORE normalization
      # This allows "K8s" to match before it becomes "K 8 s"
      abbreviation_terms = SearchAbbreviationService.expand_query(query)

      # Step 2: Normalize (PascalCase, letter-number, separators)
      normalized = normalize(query)

      # Step 3: Also expand abbreviations on normalized query
      # This catches cases like "RHEL-9" → "RHEL 9" where RHEL needs expansion
      normalized_abbrev_terms = SearchAbbreviationService.expand_query(normalized)
      abbreviation_terms = (abbreviation_terms + normalized_abbrev_terms).uniq

      # Step 4: Expand filenames (sshd.conf → sshd conf for pg_search)
      filename_terms = expand_filenames(normalized)

      # Combine all terms for ILIKE searches
      # This allows both exact "sshd.conf" matches AND "sshd conf" word matches
      ilike_terms = (abbreviation_terms + filename_terms).uniq

      # For pg_search, use the space-separated version if it's a filename
      # This enables word-based matching in PostgreSQL full-text search
      pg_search_term = filename_terms.last

      {
        ilike_terms: ilike_terms,
        pg_search_term: pg_search_term,
        normalized: normalized,
        has_phrases: false
      }
    end

    ##
    # Normalize search query for flexible matching
    #
    # Transformations:
    # - "RedHat" → "Red Hat" (split PascalCase)
    # - "RHEL9" → "RHEL 9" (split letter-number boundaries)
    # - "RHEL-9" → "RHEL 9" (normalize dashes/underscores)
    #
    # Note: Dots are NOT normalized here - they're handled in expand_filenames
    # to preserve exact matches for filenames like "sshd.conf"
    #
    # @param query [String] the search query
    # @return [String] normalized query
    #
    def normalize(query)
      normalized = query.dup

      # Split PascalCase: "RedHat" → "Red Hat"
      # Matches lowercase followed by uppercase
      normalized.gsub!(/([a-z])([A-Z])/, '\1 \2')

      # Split letter-number boundaries: "RHEL9" → "RHEL 9", "Win10" → "Win 10"
      normalized.gsub!(/([a-zA-Z])(\d)/, '\1 \2')
      normalized.gsub!(/(\d)([a-zA-Z])/, '\1 \2')

      # Normalize common separators to spaces: "RHEL-9" → "RHEL 9"
      normalized.gsub!(/[-_]/, ' ')

      # Collapse multiple spaces
      normalized.gsub!(/\s+/, ' ')

      normalized.strip
    end

    ##
    # Expand filename patterns for pg_search compatibility
    #
    # PostgreSQL's tsearch parser treats "sshd.conf" as a "host" token,
    # which doesn't match word-based searches. This method adds a
    # space-separated variant so both exact ILIKE matches and pg_search
    # word matches work.
    #
    # Examples:
    #   "sshd.conf" → ["sshd.conf", "sshd conf"]
    #   "nginx.conf" → ["nginx.conf", "nginx conf"]
    #   "sshd" → ["sshd"] (no change - already a word)
    #   "some text" → ["some text"] (no filename pattern)
    #
    # @param query [String] the normalized query
    # @return [Array<String>] original + expanded terms
    #
    def expand_filenames(query)
      terms = [query]

      # Match filename patterns like "word.extension"
      # Only expand for known config/text file extensions to avoid false positives
      extension_pattern = FILENAME_EXTENSIONS.join('|')
      if /\A(\w+)\.(#{extension_pattern})\z/i.match?(query)
        # Add space-separated version for pg_search word matching
        terms << query.tr('.', ' ')
      end

      terms
    end

    ##
    # Extract quoted phrases and unquoted terms from query
    #
    # Supports both double and single quotes for phrase search.
    # Mixed queries with both phrases and regular terms are supported.
    #
    # Examples:
    #   '"I want this"' → { phrases: ["I want this"], terms: [], has_phrases: true }
    #   '"exact phrase" other' → { phrases: ["exact phrase"], terms: ["other"], has_phrases: true }
    #   'regular search' → { phrases: [], terms: ["regular", "search"], has_phrases: false }
    #
    # @param query [String] the raw query
    # @return [Hash] with :phrases, :terms, :has_phrases, :original
    #
    def extract_phrases(query)
      phrases = []
      remaining = query.dup

      # Extract double-quoted phrases: "phrase here"
      remaining.gsub!(/"([^"]+)"/) do |_match|
        phrases << ::Regexp.last_match(1).strip
        ''
      end

      # Extract single-quoted phrases: 'phrase here'
      remaining.gsub!(/'([^']+)'/) do |_match|
        phrases << ::Regexp.last_match(1).strip
        ''
      end

      # Remaining text becomes regular search terms
      terms = remaining.split.compact_blank

      {
        phrases: phrases,
        terms: terms,
        has_phrases: phrases.any?,
        original: query
      }
    end

    ##
    # Build search result for phrase queries
    #
    # Converts phrases to PostgreSQL's FOLLOWED BY operator (<->) for exact phrase matching.
    # Regular terms use standard AND matching.
    #
    # @param phrase_result [Hash] output from extract_phrases
    # @return [Hash] standard transform result
    #
    def build_phrase_result(phrase_result)
      phrases = phrase_result[:phrases]
      terms = phrase_result[:terms]

      # Build ILIKE terms - use exact phrase for ILIKE
      ilike_terms = phrases.dup

      # Build pg_search term with FOLLOWED BY operators for phrases
      # PostgreSQL tsquery: 'word1' <-> 'word2' means word2 immediately follows word1
      pg_parts = []

      phrases.each do |phrase|
        words = phrase.split.compact_blank
        next if words.empty?

        pg_parts << if words.length == 1
                      # Single word "phrase" - just treat as regular term
                      words.first
                    else
                      # Multi-word phrase - join with <-> (FOLLOWED BY)
                      # Format: word1 <-> word2 <-> word3
                      words.join(' <-> ')
                    end
      end

      # Add regular terms with standard AND matching
      pg_parts.concat(terms)

      # For the normalized display, keep quotes
      normalized = phrase_result[:original]

      {
        ilike_terms: ilike_terms + terms,
        pg_search_term: pg_parts.join(' '),
        normalized: normalized,
        has_phrases: true
      }
    end

    private

    def empty_result
      {
        ilike_terms: [],
        pg_search_term: '',
        normalized: '',
        has_phrases: false
      }
    end
  end
end
