# frozen_string_literal: true

# Slim serializer for Audit - used in list/index views
# Only includes fields needed for table display
class AuditIndexBlueprint < Blueprinter::Base
  identifier :id

  fields :auditable_type,
         :auditable_id,
         :action,
         :version,
         :remote_address,
         :created_at

  # User info
  field :user_id
  field :user_name do |audit, options|
    user = options[:users_by_id]&.[](audit.user_id)
    user&.name || audit.username || 'System'
  end

  # Brief summary of what changed for list view
  field :changes_summary do |audit|
    changes = audit.audited_changes
    next '' if changes.blank?

    fields = changes.keys.take(3)
    summary = fields.map { |f| f.to_s.humanize }.join(', ')
    summary += ", +#{changes.keys.length - 3} more" if changes.keys.length > 3
    summary
  end
end
