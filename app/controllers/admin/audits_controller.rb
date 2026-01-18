# frozen_string_literal: true

module Admin
  # Admin controller for audit log viewing.
  # Provides read-only access to the audited gem's audit trail.
  # Supports pagination, filtering by type/action/user, and date range queries.
  #
  # Uses Blueprinter for efficient JSON serialization and Rails caching
  # for frequently accessed stats.
  class AuditsController < BaseController
    # GET /admin/audits
    # Supports pagination and filtering:
    #   - page, per_page: pagination (default 50 per page)
    #   - auditable_type: filter by model type (e.g., 'Rule', 'Component')
    #   - action_type: filter by action type ('create', 'update', 'destroy')
    #   - user_id: filter by user who made the change
    #   - from_date, to_date: date range filtering
    #   - search: search in audited_changes JSON
    def index
      @audits = apply_filters(base_scope)

      respond_to do |format|
        format.html # renders SPA layout
        format.json { render json: audits_json_with_pagination }
      end
    end

    # GET /admin/audits/:id
    def show
      @audit = Audited::Audit.find(params[:id])

      respond_to do |format|
        format.html { redirect_to admin_audits_path }
        format.json { render json: audit_detail_json }
      end
    end

    # GET /admin/audits/stats
    # Returns summary statistics for the audit log
    # Cached for 5 minutes since stats don't need real-time accuracy
    def stats
      stats_data = Rails.cache.fetch('admin/audits/stats', expires_in: 5.minutes) do
        {
          total_audits: Audited::Audit.count,
          audits_today: Audited::Audit.where('created_at >= ?', Time.zone.today).count,
          audits_this_week: Audited::Audit.where('created_at >= ?', 1.week.ago).count,
          by_type: Audited::Audit.group(:auditable_type).count,
          by_action: Audited::Audit.group(:action).count,
          cached_at: Time.current
        }
      end

      render json: stats_data
    end

    private

    # Base scope with select optimization - only select columns we need
    def base_scope
      Audited::Audit
        .select(:id, :auditable_type, :auditable_id, :action, :version,
                :user_id, :username, :audited_changes, :comment,
                :remote_address, :request_uuid, :created_at,
                :associated_type, :associated_id)
        .order(created_at: :desc)
    end

    # Apply filters and return paginated scope
    def apply_filters(scope)
      # Filter by auditable type (model class)
      scope = scope.where(auditable_type: params[:auditable_type]) if params[:auditable_type].present?

      # Filter by action (use action_type to avoid conflict with Rails action)
      scope = scope.where(action: params[:action_type]) if params[:action_type].present?

      # Filter by user who made the change
      scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?

      # Date range filtering
      if params[:from_date].present?
        from_date = Date.parse(params[:from_date]).beginning_of_day
        scope = scope.where('created_at >= ?', from_date)
      end

      if params[:to_date].present?
        to_date = Date.parse(params[:to_date]).end_of_day
        scope = scope.where('created_at <= ?', to_date)
      end

      # Text search in changes (basic LIKE search on JSON column)
      if params[:search].present?
        search_term = "%#{params[:search].downcase}%"
        scope = scope.where('LOWER(CAST(audited_changes AS TEXT)) LIKE ?', search_term)
      end

      scope
    end

    def audits_json_with_pagination
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 50).to_i.clamp(10, 100)
      # Use count(:id) to avoid PostgreSQL error with select columns
      total = @audits.count(:id)
      paginated_audits = @audits.offset((page - 1) * per_page).limit(per_page)

      # Preload users for efficiency (batch load instead of N+1)
      user_ids = paginated_audits.pluck(:user_id).compact.uniq
      users_by_id = User.where(id: user_ids).index_by(&:id)

      {
        audits: AuditIndexBlueprint.render_as_hash(paginated_audits, users_by_id: users_by_id),
        pagination: {
          page: page,
          per_page: per_page,
          total: total,
          total_pages: (total.to_f / per_page).ceil
        },
        filters: available_filters
      }
    end

    def audit_detail_json
      # Get the user for this audit
      users_by_id = if @audit.user_id
                      { @audit.user_id => User.find_by(id: @audit.user_id) }.compact
                    else
                      {}
                    end

      {
        audit: AuditBlueprint.render_as_hash(@audit, users_by_id: users_by_id)
      }
    end

    # Return available filter options for the UI
    # Cached for 10 minutes since these don't change often
    def available_filters
      Rails.cache.fetch('admin/audits/filters', expires_in: 10.minutes) do
        {
          auditable_types: Audited::Audit.distinct.pluck(:auditable_type).compact.sort,
          actions: Audited::Audit.distinct.pluck(:action).compact.sort
        }
      end
    end
  end
end
