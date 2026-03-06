# frozen_string_literal: true

module Api
  ##
  # API controller for global search functionality
  # Returns search results across projects, components, rules, SRGs, and STIGs
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
        rules: search_rules(limit),
        srgs: search_srgs(limit),
        stigs: search_stigs(limit),
        stig_rules: search_stig_rules(limit),
        srg_rules: search_srg_rules(limit)
      }
    end

    private

    def empty_results
      { projects: [], components: [], rules: [], srgs: [], stigs: [], stig_rules: [], srg_rules: [] }
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
      project_ids = current_user.available_projects.ids

      # Build conditions: search name, prefix, AND metadata JSON values (F2)
      name_prefix_conds = build_ilike_conditions(%w[components.name components.prefix])
      metadata_cond = build_metadata_ilike_condition

      Component.left_joins(:component_metadata)
               .where(project_id: project_ids)
               .where("(#{name_prefix_conds[0]}) OR (#{metadata_cond[0]})",
                      *name_prefix_conds[1..], *metadata_cond[1..])
               .includes(:project, :component_metadata)
               .distinct
               .limit(limit)
               .map do |component|
        {
          id: component.id,
          name: component.name,
          version: component.version,
          release: component.release,
          project_id: component.project_id,
          project_name: component.project&.name,
          metadata: component.component_metadata&.data
        }
      end
    end

    def search_rules(limit)
      return [] unless current_user

      # Get components from user's available projects
      project_ids = current_user.available_projects.ids
      component_ids = Component.where(project_id: project_ids).ids

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
    # Search SRGs (Security Requirements Guides)
    # SRGs are public resources - any authenticated user can search them
    #
    def search_srgs(limit)
      SecurityRequirementsGuide
        .where(*build_ilike_conditions(%w[name title srg_id]))
        .limit(limit)
        .map do |srg|
          {
            id: srg.id,
            srg_id: srg.srg_id,
            name: srg.name,
            title: srg.title,
            version: srg.version
          }
        end
    end

    ##
    # Search STIGs (Security Technical Implementation Guides)
    # STIGs are public resources - any authenticated user can search them
    #
    def search_stigs(limit)
      Stig
        .where(*build_ilike_conditions(%w[name title stig_id description]))
        .limit(limit)
        .map do |stig|
          {
            id: stig.id,
            stig_id: stig.stig_id,
            name: stig.name,
            title: stig.title,
            version: stig.version,
            description: stig.description
          }
        end
    end

    ##
    # Search STIG Rules (rules within published STIGs)
    # STIG rules are public resources - any authenticated user can search them
    # Searches: rule_id, vuln_id, title, fixtext, ident (CCIs), check content
    #
    def search_stig_rules(limit)
      # Build search across rule fields and joined check content
      conditions = build_stig_rule_conditions

      StigRule
        .left_joins(:checks)
        .where(conditions)
        .includes(:stig)
        .distinct
        .limit(limit)
        .map do |rule|
          {
            id: rule.id,
            rule_id: rule.rule_id,
            vuln_id: rule.vuln_id,
            title: rule.title,
            fixtext: rule.fixtext,
            ident: rule.ident,
            stig_id: rule.stig_id,
            stig_name: rule.stig&.name
          }
        end
    end

    ##
    # Search SRG Rules (rules within Security Requirements Guides)
    # SRG rules are public resources - any authenticated user can search them
    # Searches: rule_id, title, fixtext, ident (CCIs), check content
    #
    def search_srg_rules(limit)
      # Build search across rule fields and joined check content
      conditions = build_srg_rule_conditions

      SrgRule
        .left_joins(:checks)
        .where(conditions)
        .includes(:security_requirements_guide)
        .distinct
        .limit(limit)
        .map do |rule|
          {
            id: rule.id,
            rule_id: rule.rule_id,
            title: rule.title,
            fixtext: rule.fixtext,
            ident: rule.ident,
            srg_id: rule.security_requirements_guide_id,
            srg_name: rule.security_requirements_guide&.name
          }
        end
    end

    ##
    # Build ILIKE conditions for STIG rule search across multiple fields
    # Including check content via join
    #
    # Security: Column names are hardcoded literals below, user input is parameterized via ?.
    # See build_ilike_conditions for detailed security explanation.
    #
    def build_stig_rule_conditions
      columns = %w[base_rules.rule_id base_rules.vuln_id base_rules.title base_rules.fixtext base_rules.ident]
      check_columns = %w[checks.content]

      conditions = []
      values = []

      @search_terms.each do |term|
        sanitized_term = ActiveRecord::Base.sanitize_sql_like(term)
        rule_conditions = columns.map { |col| "#{col} ILIKE ?" }.join(' OR ')
        check_conditions = check_columns.map { |col| "#{col} ILIKE ?" }.join(' OR ')
        conditions << "(#{rule_conditions} OR #{check_conditions})"

        columns.size.times { values << "%#{sanitized_term}%" }
        check_columns.size.times { values << "%#{sanitized_term}%" }
      end

      [conditions.join(' OR ')] + values
    end

    ##
    # Build ILIKE conditions for SRG rule search across multiple fields
    # Including check content via join
    #
    # Security: Column names are hardcoded literals below, user input is parameterized via ?.
    # See build_ilike_conditions for detailed security explanation.
    #
    def build_srg_rule_conditions
      columns = %w[base_rules.rule_id base_rules.title base_rules.fixtext base_rules.ident]
      check_columns = %w[checks.content]

      conditions = []
      values = []

      @search_terms.each do |term|
        sanitized_term = ActiveRecord::Base.sanitize_sql_like(term)
        rule_conditions = columns.map { |col| "#{col} ILIKE ?" }.join(' OR ')
        check_conditions = check_columns.map { |col| "#{col} ILIKE ?" }.join(' OR ')
        conditions << "(#{rule_conditions} OR #{check_conditions})"

        columns.size.times { values << "%#{sanitized_term}%" }
        check_columns.size.times { values << "%#{sanitized_term}%" }
      end

      [conditions.join(' OR ')] + values
    end

    ##
    # Build ILIKE conditions for multiple search terms across multiple columns
    # Returns array suitable for .where(*result)
    #
    # Security: This is NOT vulnerable to SQL injection despite CodeQL alerts.
    # - Column names are hardcoded string literals, never from user input
    # - User input goes through sanitize_sql_like() then into ? placeholders
    # - The generated SQL uses parameterized queries: "name ILIKE ?" with bind values
    #
    # Search metadata JSON values by casting to text and using ILIKE
    def build_metadata_ilike_condition
      conditions = []
      values = []

      @search_terms.each do |term|
        sanitized_term = ActiveRecord::Base.sanitize_sql_like(term)
        conditions << 'CAST(component_metadata.data AS text) ILIKE ?'
        values << "%#{sanitized_term}%"
      end

      return ['1=0'] if conditions.empty?

      [conditions.join(' OR ')] + values
    end

    def build_ilike_conditions(columns)
      conditions = []
      values = []

      @search_terms.each do |term|
        sanitized_term = ActiveRecord::Base.sanitize_sql_like(term)
        column_conditions = columns.map { |col| "#{col} ILIKE ?" }.join(' OR ')
        conditions << "(#{column_conditions})"
        # Add the sanitized term value for each column
        columns.size.times { values << "%#{sanitized_term}%" }
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

      match = searchable_fields.find do |field_info|
        content = field_info[:content].to_s
        next if content.blank?

        content_lower = content.downcase
        query_words.all? { |word| content_lower.include?(word) }
      end

      return nil unless match

      extract_snippet(match[:content].to_s, query_words.first, match[:field])
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
