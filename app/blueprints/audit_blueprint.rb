# frozen_string_literal: true

# Full serializer for Audit - used in detail views
class AuditBlueprint < Blueprinter::Base
  identifier :id

  fields :auditable_type,
         :auditable_id,
         :associated_type,
         :associated_id,
         :action,
         :version,
         :audited_changes,
         :comment,
         :request_uuid,
         :remote_address,
         :created_at

  # User info - may be nil for system actions
  field :user_id
  field :user_name do |audit, options|
    user = options[:users_by_id]&.[](audit.user_id)
    user&.name || audit.username || 'System'
  end

  field :user_email do |audit, options|
    options[:users_by_id]&.[](audit.user_id)&.email
  end

  # Check if the auditable record still exists
  field :auditable_exists do |audit|
    audit.auditable.present?
  rescue StandardError
    false
  end

  # Display name for the auditable object
  field :auditable_name do |audit|
    auditable = begin
      audit.auditable
    rescue StandardError
      nil
    end

    next nil unless auditable

    case auditable
    when User
      auditable.name
    when Component
      auditable.name
    when Project
      auditable.name
    when Rule
      "Rule #{auditable.rule_id}"
    else
      auditable.try(:name) || "#{auditable.class.name} ##{auditable.id}"
    end
  end
end
