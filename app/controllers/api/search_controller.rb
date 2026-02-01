# frozen_string_literal: true

module Api
  ##
  # API controller for global search functionality
  # Returns search results across projects, components, and rules
  #
  class SearchController < BaseController
    before_action :authenticate_user!

    def global
      raw_query = params[:q].to_s.strip
      limit = (params[:limit] || 5).to_i.clamp(1, 20)

      return render json: empty_results if raw_query.length < 2

      # Transform query using centralized service
      # Handles normalization, abbreviation expansion, filename expansion, and phrase detection
      @query = SearchQueryService.transform(raw_query)

      # For ILIKE searches (projects, components)
      @search_terms = @query[:ilike_terms]

      # For pg_search (rules) - use space-separated version for word matching
      @pg_search_term = @query[:pg_search_term]

      # For phrase search - use raw query with quotes for websearch_to_tsquery
      @has_phrases = @query[:has_phrases]
      @raw_query = raw_query

      render json: {
        projects: search_projects(limit),
        components: search_components(limit),
        rules: search_rules(limit)
      }
    end

    private

    def empty_results
      { projects: [], components: [], rules: [] }
    end

    def search_projects(limit)
      return [] unless current_user

      current_user.available_projects
                  .where(*build_ilike_conditions(%w[name description]))
                  .limit(limit)
                  .map do |project|
        {
          id: project.id,
          name: project.name,
          description: project.description,
          components_count: project.components.count
        }
      end
    end

    def search_components(limit)
      return [] unless current_user

      # Get components from user's available projects
      project_ids = current_user.available_projects.pluck(:id)

      Component.where(project_id: project_ids)
               .where(*build_ilike_conditions(%w[name prefix]))
               .includes(:project)
               .limit(limit)
               .map do |component|
        {
          id: component.id,
          name: component.name,
          version: component.version,
          release: component.release,
          project_id: component.project_id,
          project_name: component.project&.name
        }
      end
    end

    def search_rules(limit)
      return [] unless current_user

      # Get components from user's available projects
      project_ids = current_user.available_projects.pluck(:id)
      component_ids = Component.where(project_id: project_ids).pluck(:id)

      # Use phrase search (websearch_to_tsquery) for quoted phrases
      # Otherwise use pg_search with word matching
      rules_scope = Rule.where(component_id: component_ids)

      rules_scope = if @has_phrases
                      # Phrase search - use websearch_to_tsquery which supports "exact phrase"
                      rules_scope.search_phrase(@raw_query)
                    else
                      # Regular search - use pg_search with prefix matching
                      search_term = @pg_search_term || @search_terms.first
                      rules_scope.search_content(search_term)
                    end

      rules_scope.includes(:component, :disa_rule_descriptions, :checks)
                 .limit(limit)
                 .map do |rule|
        {
          id: rule.id,
          rule_id: rule.rule_id,
          title: rule.title,
          status: rule.status,
          component_id: rule.component_id,
          component_prefix: rule.component&.prefix,
          snippet: generate_snippet(rule, @query[:normalized])
        }
      end
    end

    ##
    # Build ILIKE conditions for multiple search terms across multiple columns
    # Returns array suitable for .where(*result)
    #
    def build_ilike_conditions(columns)
      conditions = []
      values = []

      @search_terms.each do |term|
        column_conditions = columns.map { |col| "#{col} ILIKE ?" }.join(' OR ')
        conditions << "(#{column_conditions})"
        # Add the term value for each column
        columns.size.times { values << "%#{term}%" }
      end

      [conditions.join(' OR ')] + values
    end

    ##
    # Generate a snippet showing context around the search match
    # Searches through title, fixtext, vuln_discussion, and check content
    #
    def generate_snippet(rule, query)
      searchable_fields = [
        { field: 'title', content: rule.title },
        { field: 'fixtext', content: rule.fixtext },
        { field: 'vuln_discussion', content: rule.disa_rule_descriptions.first&.vuln_discussion },
        { field: 'check', content: rule.checks.first&.content }
      ]

      # Find which field contains the match
      query_words = query.downcase.split(/\s+/)

      searchable_fields.each do |field_info|
        content = field_info[:content].to_s
        next if content.blank?

        # Check if this field contains the query
        content_lower = content.downcase
        if query_words.all? { |word| content_lower.include?(word) }
          # Found match - extract snippet around first occurrence
          return extract_snippet(content, query_words.first, field_info[:field])
        end
      end

      nil
    end

    ##
    # Extract a snippet of text around the match
    #
    def extract_snippet(content, query_word, field_name)
      return nil if content.blank?

      # Find position of match (case-insensitive)
      pos = content.downcase.index(query_word.downcase)
      return nil unless pos

      # Extract ~80 chars around the match
      start_pos = [pos - 40, 0].max
      end_pos = [pos + query_word.length + 40, content.length].min

      snippet = content[start_pos...end_pos]

      # Add ellipses if truncated
      snippet = "...#{snippet}" if start_pos.positive?
      snippet = "#{snippet}..." if end_pos < content.length

      # Add field context
      field_label = field_name.humanize
      "[#{field_label}] #{snippet}"
    end
  end
end
