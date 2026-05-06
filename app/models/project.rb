# frozen_string_literal: true

# Projects are home to a collection of Components and are managed by Users.
class Project < ApplicationRecord
  attr_accessor :current_user

  enum :visibility, { discoverable: 0, hidden: 1 }

  include VulcanAuditable

  vulcan_audited except: %i[id admin_name admin_email memberships_count]
  has_associated_audits

  has_many :memberships, -> { includes :user }, as: :membership, inverse_of: :membership, dependent: :destroy
  has_many :users, through: :memberships
  has_many :components, dependent: :destroy
  has_many :rules, through: :components
  has_many :access_requests, class_name: 'ProjectAccessRequest', dependent: :destroy
  has_one :project_metadata, dependent: :destroy
  accepts_nested_attributes_for :project_metadata, :memberships

  # Length limits — configurable via Settings.input_limits (env vars: VULCAN_LIMIT_PROJECT_*)
  validates :name, presence: true, length: { maximum: ->(_r) { Settings.input_limits.project_name } }
  validates :description, length: { maximum: ->(_r) { Settings.input_limits.project_description } }
  validates :admin_name, :admin_email,
            length: { maximum: ->(_r) { Settings.input_limits.short_string } }, allow_nil: true

  scope :alphabetical, -> { order(:name) }

  # The reviews→base_rules→components chain needs an explicit INNER JOIN to
  # components because base_rules is the Rule STI table; AR's `joins(:rule)`
  # alone doesn't resolve the components alias used in GROUP BY / HAVING.
  # Pulled out as a constant so all three project-comment aggregate queries
  # share the same join.
  REVIEW_RULE_COMPONENT_JOIN = 'INNER JOIN components ON components.id = base_rules.component_id'
  private_constant :REVIEW_RULE_COMPONENT_JOIN

  # Aggregate count of top-level pending comments per project. Used by the
  # projects-list page to render a "N pending comments" badge per row
  # without N+1 queries.
  #
  # Returns a sparse hash: { project_id => count } — projects with zero
  # pending comments are omitted so callers can `counts[id] || 0`.
  #
  # Single SQL query joins reviews → base_rules (Rule STI) → components,
  # filters to top-level pending comment Reviews, groups by project_id.
  def self.pending_comment_counts(project_ids)
    return {} if project_ids.blank?

    Review.where(action: 'comment',
                 responding_to_review_id: nil,
                 triage_status: 'pending')
          .joins(:rule)
          .merge(Rule.where(component: Component.where(project_id: project_ids)))
          .joins(REVIEW_RULE_COMPONENT_JOIN)
          .group('components.project_id')
          .count
  end

  # Pending + total top-level comment counts per project, returned as a
  # sparse hash: { project_id => { pending: N, total: M } }. Drives the
  # projects-list "Comments" column — pending is the
  # action-needed metric, total is the ambient activity metric.
  #
  # Single GROUP BY using Postgres FILTER aggregate so we count both
  # without a second query. Projects with zero top-level comments are
  # omitted; callers can `result[id] || { pending: 0, total: 0 }`.
  def self.comment_counts(project_ids)
    return {} if project_ids.blank?

    rows = Review.where(action: 'comment', responding_to_review_id: nil)
                 .joins(:rule)
                 .merge(Rule.where(component: Component.where(project_id: project_ids)))
                 .joins(REVIEW_RULE_COMPONENT_JOIN)
                 .group('components.project_id')
                 .pluck(
                   Arel.sql('components.project_id'),
                   Arel.sql("COUNT(*) FILTER (WHERE reviews.triage_status = 'pending')"),
                   Arel.sql('COUNT(*)')
                 )
    rows.each_with_object({}) do |(pid, pending, total), h|
      h[pid] = { pending: pending, total: total }
    end
  end

  # Per-project deep-link target for the projects-list "Comments" column.
  # Returns the unique pending component_id ONLY when a project has
  # exactly one component with pending comments — letting the list link
  # bypass the project page entirely (one click → triage panel). When a
  # project has multiple pending components, callers fall back to the
  # project-detail page so the user can pick.
  #
  # Returns a sparse hash: { project_id => component_id } — projects
  # with 0 or 2+ pending components are omitted. Single GROUP-BY-HAVING.
  def self.pending_comment_target_components(project_ids)
    return {} if project_ids.blank?

    rows = Review.where(action: 'comment',
                        responding_to_review_id: nil,
                        triage_status: 'pending')
                 .joins(:rule)
                 .merge(Rule.where(component: Component.where(project_id: project_ids)))
                 .joins(REVIEW_RULE_COMPONENT_JOIN)
                 .group('components.project_id')
                 .having('COUNT(DISTINCT base_rules.component_id) = 1')
                 .pluck('components.project_id', 'MIN(base_rules.component_id)')
    rows.to_h
  end

  # Backs GET /projects/:id/comments — same row shape as
  # Component#paginated_comments but aggregated across ALL the project's
  # components, with a component_id + component_name on each row so the
  # full-page triage view can show which component each comment belongs to.
  #
  # Filters mirror the per-component endpoint. Vocabulary on the wire is
  # DISA-native; UI translates via triageVocabulary.js.
  def paginated_comments(triage_status: 'all', section: nil, component_id: nil,
                         author_id: nil, query: nil, page: 1, per_page: 25,
                         resolved: 'all')
    page = [page.to_i, 1].max
    per_page = per_page.to_i.clamp(1, 100)

    project_components = components.to_a
    component_ids_in_project = project_components.map(&:id)
    return { rows: [], pagination: { page: 1, per_page: per_page, total: 0 } } if component_ids_in_project.empty?

    scope_components = component_id.present? ? [component_id.to_i] & component_ids_in_project : component_ids_in_project
    return { rows: [], pagination: { page: 1, per_page: per_page, total: 0 } } if scope_components.empty?

    scope = Review.top_level_comments
                  .joins(:rule)
                  .merge(Rule.where(component_id: scope_components))
                  .preload(:user, :triage_set_by, :adjudicated_by)

    scope = scope.where(triage_status: triage_status) unless triage_status == 'all'
    scope = scope.where(section: section) if section.present? && section != 'all'
    scope = scope.where(user_id: author_id) if author_id.present?

    resolved_str = resolved.to_s
    if resolved_str == 'true'
      scope = scope.where.not(adjudicated_at: nil)
    elsif resolved_str == 'false'
      scope = scope.where(adjudicated_at: nil)
    end

    if query.present?
      escaped = ActiveRecord::Base.sanitize_sql_like(query.to_s)
      scope = scope.where('reviews.comment ILIKE ?', "%#{escaped}%")
    end

    total = scope.count

    component_lookup = project_components.index_by(&:id)

    # Materialize the page first, then look up ONLY the rules referenced by
    # the page's rows. The previous implementation pre-loaded every rule in
    # the project (component_id IN scope) — for projects with thousands of
    # rules that's a tens-of-thousands-of-rows query just to decorate one
    # page of comments. (Code-review finding #7.)
    page_reviews = scope.order(created_at: :desc)
                        .offset((page - 1) * per_page)
                        .limit(per_page)
                        .to_a
    page_rule_ids = page_reviews.map(&:rule_id).uniq
    rule_lookup = Rule.where(id: page_rule_ids).pluck(:id, :rule_id, :component_id).to_h do |rid, rule_id, cid|
      [rid, { rule_id: rule_id, component_id: cid, prefix: component_lookup[cid]&.prefix }]
    end

    page_review_ids = page_reviews.map(&:id)
    responses_count_lookup = Review.where(responding_to_review_id: page_review_ids)
                                   .group(:responding_to_review_id)
                                   .count
    reaction_counts = Reaction.where(review_id: page_review_ids).group(:review_id, :kind).count

    rows = page_reviews.map do |r|
      rule_meta = rule_lookup[r.rule_id] || {}
      cid = rule_meta[:component_id]
      {
        id: r.id,
        rule_id: r.rule_id,
        rule_displayed_name: rule_meta[:prefix] ? "#{rule_meta[:prefix]}-#{rule_meta[:rule_id]}" : nil,
        component_id: cid,
        component_name: component_lookup[cid]&.name,
        section: r.section,
        author_name: r.user&.name,
        # author_email intentionally omitted — see Component#paginated_comments
        # for rationale (PII scraping during public review windows).
        comment: r.comment,
        created_at: r.created_at,
        triage_status: r.triage_status,
        triage_set_at: r.triage_set_at,
        adjudicated_at: r.adjudicated_at,
        duplicate_of_review_id: r.duplicate_of_review_id,
        triager_display_name: r.triager_display_name,
        triager_imported: r.triager_imported?,
        adjudicator_display_name: r.adjudicator_display_name,
        adjudicator_imported: r.adjudicator_imported?,
        responses_count: responses_count_lookup[r.id] || 0,
        reactions: { up: reaction_counts[[r.id, 'up']] || 0,
                     down: reaction_counts[[r.id, 'down']] || 0 }
      }
    end

    { rows: rows, pagination: { page: page, per_page: per_page, total: total } }
  end

  # Helper method to extract data from Project Metadata
  def metadata
    project_metadata&.data
  end

  def admins
    memberships.where(
      role: 'admin'
    ).eager_load(:user).select(:user_id, :name, :email)
  end

  def update_admin_contact_info
    project_admin = admins.first
    if project_admin
      self.admin_name = project_admin.name
      self.admin_email = project_admin.email
    else
      self.admin_name = nil
      self.admin_email = nil
    end
    save
    components.each(&:update_admin_contact_info)
  end

  ##
  # Get a list of Users that are not yet members of this project
  #
  def available_members
    User.where.not(id: users.select(:id)).select(:id, :name, :email)
  end

  def search_available_members(query, limit: 10)
    sanitized = ActiveRecord::Base.sanitize_sql_like(query)
    available_members
      .where('users.name ILIKE :q OR users.email ILIKE :q', q: "%#{sanitized}%")
      .limit(limit)
  end

  def search_members(query, limit: 10)
    sanitized = ActiveRecord::Base.sanitize_sql_like(query)
    users.where('users.name ILIKE :q OR users.email ILIKE :q', q: "%#{sanitized}%")
         .select(:id, :name, :email)
         .limit(limit)
  end

  def details
    status_counts = rules.group(:status).count
    lock_counts = rules.group(:locked).count
    review_counts = rules.where(locked: false).group(
      Arel.sql('CASE WHEN review_requestor_id IS NULL THEN \'nur\' ELSE \'ur\' END')
    ).count

    {
      ac: status_counts['Applicable - Configurable'] || 0,
      aim: status_counts['Applicable - Inherently Meets'] || 0,
      adnm: status_counts['Applicable - Does Not Meet'] || 0,
      na: status_counts['Not Applicable'] || 0,
      nyd: status_counts['Not Yet Determined'] || 0,
      nur: review_counts['nur'] || 0,
      ur: review_counts['ur'] || 0,
      lck: lock_counts[true] || 0,
      total: status_counts.values.sum
    }
  end

  ##
  # Get a list of projects that can be added as components to this project
  def available_components
    # Don't allow importing a component twice to the same project
    reject_component_ids = components.pluck(:id, :component_id).flatten.compact
    # Assumption that released components are publicly available within vulcan
    # rules_count + component_id required by ComponentBlueprint :index for the
    # controls badge and (Overlaid) tag on ComponentCard.
    Component.where(released: true).where.not(id: reject_component_ids)
             .select(:id, :name, :prefix, :version, :release, :project_id,
                     :security_requirements_guide_id, :released, :updated_at,
                     :rules_count, :component_id)
  end
end
