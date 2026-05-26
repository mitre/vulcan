# frozen_string_literal: true

# Builds paginated, filtered comment queries for a Component.
class CommentQueryService
  def initialize(component, params = {})
    @component = component
    @triage_status = params[:triage_status] || 'all'
    @section = params[:section]
    @rule_id = params[:rule_id]
    @author_id = params[:author_id]
    @query = params[:query]
    @page = [params.fetch(:page, 1).to_i, 1].max
    @per_page = params.fetch(:per_page, 25).to_i.clamp(1, 100)
    @resolved = params[:resolved] || 'all'
    @commentable_type = params[:commentable_type]
    @include_rule_content = params[:include_rule_content] || false
  end

  def call
    scope = build_base_scope
    base_scope_for_counts = scope
    scope = apply_filters(scope)

    total = scope.count
    total_comments = build_all_comments_scope.count
    page_records = paginate(scope)

    rows = serialize_rows(page_records)
    status_counts = base_scope_for_counts.group(:triage_status).count

    {
      rows: rows,
      pagination: { page: @page, per_page: @per_page, total: total, total_comments: total_comments },
      status_counts: status_counts
    }
  end

  private

  def rule_id_subquery
    @rule_id_subquery ||= @component.rules.select(:id)
  end

  def build_base_scope
    rule_scoped = Review.top_level_comments
                        .where(commentable_type: 'BaseRule', commentable_id: rule_id_subquery)
    component_scoped = Review.top_level_comments
                             .where(commentable_type: 'Component', commentable_id: @component.id)

    scope = case @commentable_type.to_s.downcase
            when 'component' then component_scoped
            when 'rule'      then rule_scoped
            else                  rule_scoped.or(component_scoped)
            end

    commentable_preloads = if @include_rule_content
                             { commentable: %i[disa_rule_descriptions checks] }
                           else
                             :commentable
                           end
    scope.preload(:user, :triage_set_by, :adjudicated_by, commentable_preloads)
  end

  def build_all_comments_scope
    rule_scoped = Review.where(action: Review::ACTION_COMMENT,
                               commentable_type: 'BaseRule',
                               commentable_id: rule_id_subquery)
    component_scoped = Review.where(action: Review::ACTION_COMMENT,
                                    commentable_type: 'Component',
                                    commentable_id: @component.id)

    scope = case @commentable_type.to_s.downcase
            when 'component' then component_scoped
            when 'rule'      then rule_scoped
            else                  rule_scoped.or(component_scoped)
            end

    scope = scope.where(commentable_type: 'BaseRule', commentable_id: @rule_id) if @rule_id.present?
    scope = scope.where(section: @section) if @section.present? && @section != 'all'

    if @query.present?
      escaped = ActiveRecord::Base.sanitize_sql_like(@query.to_s)
      scope = scope.where('reviews.comment ILIKE ?', "%#{escaped}%")
    end

    scope
  end

  def apply_filters(scope)
    scope = scope.where(triage_status: @triage_status) unless @triage_status == 'all'
    scope = scope.where(section: @section) if @section.present? && @section != 'all'
    scope = scope.where(commentable_type: 'BaseRule', commentable_id: @rule_id) if @rule_id.present?
    scope = scope.where(user_id: @author_id) if @author_id.present?

    case @resolved.to_s
    when 'true'  then scope = scope.where.not(adjudicated_at: nil)
    when 'false' then scope = scope.where(adjudicated_at: nil)
    end

    if @query.present?
      escaped = ActiveRecord::Base.sanitize_sql_like(@query.to_s)
      scope = scope.where('reviews.comment ILIKE ?', "%#{escaped}%")
    end

    scope
  end

  def paginate(scope)
    scope.order(created_at: :desc)
         .offset((@page - 1) * @per_page)
         .limit(@per_page)
         .to_a
  end

  def serialize_rows(page_records)
    rule_id_to_displayed = @component.rules.pluck(:id, :rule_id).to_h
                                     .transform_values { |rid| "#{@component.prefix}-#{rid}" }

    child_to_parent = RuleSatisfaction
                      .where(rule_id: rule_id_subquery)
                      .pluck(:rule_id, :satisfied_by_rule_id)
                      .to_h
    parent_id_to_displayed = child_to_parent.values.uniq.index_with { |pid| rule_id_to_displayed[pid] }

    page_review_ids = page_records.map(&:id)
    responses_count_lookup = Review.where(responding_to_review_id: page_review_ids)
                                   .group(:responding_to_review_id)
                                   .count
    reaction_counts = Reaction.where(review_id: page_review_ids).group(:review_id, :kind).count

    page_records.map do |r|
      component_scoped_row = r.commentable_type == 'Component'
      row = {
        id: r.id,
        rule_id: component_scoped_row ? nil : r.rule_id,
        rule_displayed_name: component_scoped_row ? '(component)' : rule_id_to_displayed[r.rule_id],
        commentable_type: r.commentable_type,
        section: r.section,
        author_name: r.commenter_display_name,
        author_email: r.user&.email || r.commenter_imported_email,
        comment: r.comment,
        created_at: r.created_at,
        triage_status: r.triage_status,
        triage_set_at: r.triage_set_at,
        adjudicated_at: r.adjudicated_at,
        duplicate_of_review_id: r.duplicate_of_review_id,
        addressed_by_rule_id: r.addressed_by_rule_id,
        addressed_by_rule_name: r.addressed_by_rule_id ? rule_id_to_displayed[r.addressed_by_rule_id] : nil,
        triager_display_name: r.triager_display_name,
        triager_imported: r.triager_imported?,
        adjudicator_display_name: r.adjudicator_display_name,
        adjudicator_imported: r.adjudicator_imported?,
        commenter_display_name: r.commenter_display_name,
        commenter_imported: r.commenter_imported?,
        responses_count: responses_count_lookup[r.id] || 0,
        reactions: { up: reaction_counts[[r.id, 'up']] || 0,
                     down: reaction_counts[[r.id, 'down']] || 0 },
        updated_at: r.updated_at,
        rule_status: component_scoped_row ? nil : r.commentable&.status,
        parent_rule_displayed_name: component_scoped_row ? nil : parent_id_to_displayed[child_to_parent[r.rule_id]],
        group_rule_displayed_name: nil
      }

      row[:group_rule_displayed_name] = row[:parent_rule_displayed_name] || row[:rule_displayed_name]
      row[:rule_content] = @component.serialize_rule_content(r, component_scoped_row) if @include_rule_content

      row
    end
  end
end
