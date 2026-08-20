# frozen_string_literal: true

module Api
  ##
  # API controller for global search functionality
  # Returns search results across projects, components, rules, SRGs, and STIGs
  #
  class SearchController < BaseController
    include SearchScoping

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

      projects = current_user.available_projects
                             .where(*build_ilike_conditions(%w[name description]))
                             .limit(limit)
                             .to_a

      # Batch the per-project components_count via one GROUP BY.
      counts = Component.where(project_id: projects.map(&:id))
                        .group(:project_id).count

      projects.map do |project|
        {
          id: project.id,
          name: project.name,
          description: project.description,
          components_count: counts[project.id] || 0
        }
      end
    end

    def search_components(limit)
      return [] unless current_user

      # Build conditions: search name, prefix, AND metadata JSON values (F2)
      name_prefix_conds = build_ilike_conditions(%w[components.name components.prefix])
      metadata_cond = build_metadata_ilike_condition

      # Content is membership-gated: memberships or released components,
      # never discoverable-but-not-joined projects (those grant existence
      # via the projects section, not content). Materialized ids for the
      # same planner reason as the rules search below.
      Component.left_joins(:component_metadata)
               .where(id: searchable_components.ids)
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

      # Content is membership-gated — same scope as the component results.
      # The id set is MATERIALIZED, never passed as a subselect: pg_search's
      # ts_rank subquery computes tsvectors on the fly, and a subselect here
      # let the planner re-execute that work per row — a runaway query that
      # hung the suite for an hour until its backend was terminated.
      component_ids = if params[:component_id].present?
                        comp = searchable_components.where(id: params[:component_id]).first
                        return [] unless comp

                        [comp.id]
                      else
                        searchable_components.ids
                      end

      # Requirement rows of BOTH document kinds — stig Rules and authored
      # SRG requirements — through the kind seam (a Rule-classed query
      # structurally excludes authored rows; the seam also excludes
      # tombstoned and catalog rows).
      rules_scope = BaseRule.live_for_components(component_ids)

      rules_scope = if @has_phrases
                      # Phrase search - use websearch_to_tsquery which supports "exact phrase"
                      rules_scope.search_phrase(@raw_query)
                    else
                      # Regular search - use pg_search with prefix matching
                      search_term = @pg_search_term || @search_terms.first
                      rules_scope.search_content(search_term)
                    end

      # Kind-shared associations preload on the relation; the component
      # association lives on the subclasses, so prefixes come from a batch
      # lookup on the base column instead.
      rules = rules_scope.includes(:disa_rule_descriptions, :checks)
                         .limit(limit)
                         .to_a
      prefixes = Component.where(id: rules.map(&:component_id).uniq).pluck(:id, :prefix).to_h

      # satisfied_by exists on the stig kind only — preload it for just
      # those rows (authored rows carry null parent fields).
      stig_rows = rules.grep(Rule)
      ActiveRecord::Associations::Preloader.new(records: stig_rows, associations: :satisfied_by).call if stig_rows.any?

      # Batch the per-rule comment_count via one GROUP BY.
      comment_counts = Review.where(rule_id: rules.map(&:id), action: Review::ACTION_COMMENT)
                             .group(:rule_id).count

      rules.map do |rule|
        snippet_data = generate_snippet_with_field(rule, @query[:normalized])
        parent = rule.is_a?(Rule) ? rule.satisfied_by.first : nil
        prefix = prefixes[rule.component_id]
        {
          id: rule.id,
          rule_id: rule.rule_id,
          title: rule.title,
          status: rule.status,
          component_id: rule.component_id,
          component_prefix: prefix,
          snippet: snippet_data[:snippet],
          matched_field: snippet_data[:matched_field],
          comment_count: comment_counts[rule.id] || 0,
          parent_rule_id: parent&.id,
          parent_display_name: parent ? "#{prefix}-#{parent.rule_id}" : nil
        }
      end
    end

    ##
    # Search SRGs (Security Requirements Guides)
    # SRGs are public resources - any authenticated user can search them
    #
    def search_srgs(limit)
      SecurityRequirementsGuide
        .select(:id, :srg_id, :name, :title, :version)
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
        .select(:id, :stig_id, :name, :title, :version, :description)
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
    # Searches by SUBSTRING: rule_id, vuln_id, ident (CCIs), check content;
    # by WORD (stemmed + prefixed, through the stored vector): title,
    # fixtext, and the rest of the indexed prose
    #
    def search_stig_rules(limit)
      ids = catalog_rule_match_ids(StigRule.all, limit: limit,
                                                 fragment_columns: %w[rule_id vuln_id ident])

      # Fetch by id and restore arm-priority order; parent names come from a
      # batch pluck — never a stigs.* load, which drags the multi-MB xml.
      rows = StigRule.where(id: ids).index_by(&:id)
      ordered = ids.filter_map { |id| rows[id] }
      stig_names = Stig.where(id: ordered.map(&:stig_id).uniq).pluck(:id, :name).to_h

      ordered.map do |rule|
        {
          id: rule.id,
          rule_id: rule.rule_id,
          vuln_id: rule.vuln_id,
          title: rule.title,
          fixtext: rule.fixtext,
          ident: rule.ident,
          stig_id: rule.stig_id,
          stig_name: stig_names[rule.stig_id]
        }
      end
    end

    ##
    # Search SRG Rules (rules within Security Requirements Guides)
    # SRG rules are public resources - any authenticated user can search them
    # Searches by SUBSTRING: rule_id, ident (CCIs), check content; by WORD
    # (stemmed + prefixed, through the stored vector): title, fixtext, and
    # the rest of the indexed prose
    #
    def search_srg_rules(limit)
      # Catalog rows only: component-authored SrgRules are project content
      # and are never served here — this search type is the instance-global
      # published SRG requirement catalog.
      catalog = SrgRule.where(component_id: nil)
      ids = catalog_rule_match_ids(catalog, limit: limit, fragment_columns: %w[rule_id ident])

      # Fetch by id and restore arm-priority order; parent names come from a
      # batch pluck — never an srgs.* load, which drags the multi-MB xml.
      rows = catalog.where(id: ids).index_by(&:id)
      ordered = ids.filter_map { |id| rows[id] }
      srg_names = SecurityRequirementsGuide.where(id: ordered.map(&:security_requirements_guide_id).uniq)
                                           .pluck(:id, :name).to_h

      ordered.map do |rule|
        {
          id: rule.id,
          rule_id: rule.rule_id,
          title: rule.title,
          fixtext: rule.fixtext,
          ident: rule.ident,
          srg_id: rule.security_requirements_guide_id,
          srg_name: srg_names[rule.security_requirements_guide_id]
        }
      end
    end

    ##
    # Catalog rule matching for the stig_rules/srg_rules sections — every
    # arm is served by an index, never a cross-table OR (the planner can
    # only evaluate that as a post-join filter, which no index can serve):
    # - prose (title/fixtext + associated content) matches by WORD through
    #   the stored searchable vector — stemmed and prefixed, GIN-indexed
    # - ids and CCIs match by SUBSTRING through their trigram indexes, so
    #   fragment searches like "258217" keep finding V-258217
    # - check content matches by SUBSTRING through its trigram index in a
    #   bounded single-table lookup
    # Terms union across arms (the sections' established OR-across-terms
    # semantics); each arm is capped at the section limit so id pulls stay
    # bounded.
    #
    # Security: Column names come from hardcoded literals at the call
    # sites; user input is parameterized. See build_ilike_conditions for
    # the detailed explanation.
    #
    # Returns ids in ARM-PRIORITY order — id/CCI fragment hits first, check
    # content hits second, word hits last — so an exact-id search always
    # survives the limit window and leads the results, while word matches
    # fill the remainder.
    def catalog_rule_match_ids(scope, limit:, fragment_columns:)
      fragment_sql = fragment_columns.map { |col| "base_rules.#{col} ILIKE :term" }.join(' OR ')
      fragment_ids = []
      check_ids = []
      word_ids = []

      @search_terms.each do |term|
        sanitized = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
        # Stable :id ordering inside each substring arm makes the limit
        # window deterministic (the word arm already orders by rank, id).
        # The check arm joins WITHIN the catalog scope before the bound
        # applies — a globally bounded check lookup would let
        # component-rule checks starve catalog matches. The ILIKE stays
        # single-column on checks, so its trigram index serves the join.
        fragment_ids.concat(scope.where(fragment_sql, term: sanitized).order(:id).limit(limit).ids)
        check_ids.concat(scope.joins(:checks).where('checks.content ILIKE ?', sanitized)
                              .distinct.order(:id).limit(limit).ids)
        word_ids.concat(scope.search_content(term).limit(limit).ids)
      end

      (fragment_ids + check_ids + word_ids).uniq.take(limit)
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
    def generate_snippet_with_field(rule, query)
      searchable_fields = [
        { field: 'title', content: rule.title },
        { field: 'fixtext', content: rule.fixtext },
        { field: 'vuln_discussion', content: rule.disa_rule_descriptions.first&.vuln_discussion },
        { field: 'check', content: rule.checks.first&.content }
      ]

      query_words = query.downcase.split(/\s+/)

      match = searchable_fields.find do |field_info|
        content = field_info[:content].to_s
        next if content.blank?

        content_lower = content.downcase
        query_words.all? { |word| content_lower.include?(word) }
      end

      return { snippet: nil, matched_field: nil } unless match

      snippet = extract_snippet(match[:content].to_s, query_words.first, match[:field])
      { snippet: snippet, matched_field: match[:field] }
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
