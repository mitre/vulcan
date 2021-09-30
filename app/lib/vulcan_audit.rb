# frozen_string_literal: true

# Custom Audited class for Vulcan-specific methods for interacting with audits.
class VulcanAudit < ::Audited::Audit
  belongs_to :audited_user, class_name: 'User', optional: true
  before_create :set_username, :find_and_save_audited_user

  def self.create_initial_rule_audit_from_mapping(project_id)
    {
      auditable_type: 'Rule',
      action: 'create',
      user_type: 'System',
      audited_changes: {
        project_id: project_id
      }
    }
  end

  def set_username
    self.username = user&.name
  end

  # There are 2 different users associated with an action on a user,
  # the user who is making the change and the user who the change is applied to
  def find_and_save_audited_user
    if auditable.respond_to?(:user)
      self.audited_user = auditable.user
    elsif auditable.is_a?(User)
      self.audited_user = auditable
    end
    self.audited_username = audited_user&.name
  end

  def format
    # Each audit can encompass multiple changes on the model (see audited_changes)
    {
      id: id,
      action: action,
      auditable_type: auditable_type,
      auditable_id: auditable_id,
      name: username,
      audited_name: audited_username,
      comment: comment,
      created_at: created_at,
      audited_changes: audited_changes.map do |audited_field, audited_value|
        # On creation, the `audited_value` will be a single value (i.e. not an Array)
        # After an edit, the `audited_value` will be an Array where `[0]` is prev and `[1]` is new
        {
          field: audited_field,
          prev_value: (audited_value.is_a?(Array) ? audited_value[0] : nil),
          new_value: (audited_value.is_a?(Array) ? audited_value[1] : audited_value)
        }
      end
    }
  end
end
