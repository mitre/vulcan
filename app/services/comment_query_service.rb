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
    total_comments = count_total_comments
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

  def build_base_scope
    rule_id_subquery = @component.rules.select(:id)
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

  def count_total_comments
    rule_id_subquery = @component.rules.select(:id)
    rule_replies = Review.where(action: Review::ACTION_COMMENT,
                                commentable_type: 'BaseRule',
                                commentable_id: rule_id_subquery)
    component_replies = Review.where(action: Review::ACTION_COMMENT,
                                     commentable_type: 'Component',
                                     commentable_id: @component.id)

    scope = case @commentable_type.to_s.downcase
            when 'component' then component_replies
            when 'rule'      then rule_replies
            else                  rule_replies.or(component_replies)
            end

    scope = scope.where(commentable_type: 'BaseRule', commentable_id: @rule_id) if @rule_id.present?
    scope = scope.where(section: @section) if @section.present? && @section != 'all'

    if @query.present?
      escaped = ActiveRecord::Base.sanitize_sql_like(@query.to_s)
      scope = scope.where('reviews.comment ILIKE ?', "%#{escaped}%")
    end

    scope.count
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
                      .where(rule_id: @component.rules.ids)
                      .pluck(:rule_id, :satisfied_by_rule_id)
                      .to_h
    parent_rule_map = child_to_parent.transform_values { |pid| rule_id_to_displayed[pid] }

    page_review_ids = page_records.map(&:id)
    responses_counts = Review.where(responding_to_review_id: page_review_ids)
                             .group(:responding_to_review_id).count
    reaction_counts = Reaction.where(review_id: page_review_ids).group(:review_id, :kind).count

    blueprint_options = {
      view: :component,
      rule_display_map: rule_id_to_displayed,
      parent_rule_map: parent_rule_map,
      responses_counts: responses_counts,
      reaction_counts: reaction_counts
    }

    page_records.map do |r|
      row = CommentRowBlueprint.render_as_hash(r, **blueprint_options)
      row[:rule_content] = @component.serialize_rule_content(r, r.commentable_type == 'Component') if @include_rule_content
      row
    end
  end
end
