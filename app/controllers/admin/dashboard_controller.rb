# frozen_string_literal: true

module Admin
  # Admin dashboard controller.
  # Provides stats and overview for admin users.
  class DashboardController < BaseController
    # GET /admin
    def index
      respond_to do |format|
        format.html # renders SPA layout
        format.json { render json: stats_json }
      end
    end

    # GET /admin/stats
    def stats
      render json: stats_json
    end

    private

    def stats_json
      {
        users: {
          total: User.count,
          local: User.where(provider: nil).count,
          external: User.where.not(provider: nil).count,
          admins: User.where(admin: true).count,
          locked: User.where.not(locked_at: nil).count
        },
        projects: {
          total: Project.count,
          recent: Project.where('created_at > ?', 30.days.ago).count
        },
        components: {
          total: Component.count,
          released: Component.where(released: true).count
        },
        stigs: {
          total: Stig.count
        },
        srgs: {
          total: SecurityRequirementsGuide.count
        },
        recent_activity: recent_activity
      }
    end

    def recent_activity
      Audited.audit_class
             .order(created_at: :desc)
             .limit(20)
             .map do |audit|
               {
                 id: audit.id,
                 action: audit.action,
                 auditable_type: audit.auditable_type,
                 auditable_id: audit.auditable_id,
                 auditable_name: safe_auditable_name(audit),
                 user_name: safe_user_name(audit),
                 user_id: audit.user_id,
                 created_at: audit.created_at,
                 changes: audit.audited_changes.keys
               }
             end
    end

    def safe_auditable_name(audit)
      # Avoid loading auditable if the class doesn't exist anymore
      return nil if audit.auditable_type.blank?

      begin
        audit.auditable_type.constantize
        audit.auditable&.respond_to?(:name) ? audit.auditable.name : nil
      rescue NameError
        nil
      end
    end

    def safe_user_name(audit)
      # Handle polymorphic user_type that may reference non-existent classes (e.g., "System")
      return 'System' if audit.user_type == 'System' || audit.user_id.nil?

      begin
        audit.user_type&.constantize if audit.user_type.present?
        audit.user&.name || 'System'
      rescue NameError
        'System'
      end
    end
  end
end
