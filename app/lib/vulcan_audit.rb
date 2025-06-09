# frozen_string_literal: true

require 'audited/audit'

# Custom Audited class for Vulcan-specific methods for interacting with audits.
class VulcanAudit < Audited::Audit
  belongs_to :audited_user, class_name: 'User', optional: true
  
  # In Rails 5+, belongs_to associations are required by default.
  # The parent Audited::Audit class defines `belongs_to :user, polymorphic: true`
  # which becomes required. We need to allow nil users for system-generated audits.
  
  # Remove the user presence validation that Rails adds for belongs_to associations
  # Find and remove the validation added by the parent class
  _validators[:user].reject! { |v| v.is_a?(ActiveRecord::Validations::PresenceValidator) }
  _validate_callbacks.each do |callback|
    if callback.filter.is_a?(ActiveRecord::Validations::PresenceValidator) && 
       callback.filter.attributes.include?(:user)
      _validate_callbacks.delete(callback)
    end
  end
  
  before_create :set_username, :find_and_save_audited_user, :find_and_save_associated_rule

  def set_username
    self.username = user&.name
  end

  # There are 2 different users associated with an action on a user,
  # the user who is making the change and the user who the change is applied to.
  #
  # This function saves information for the user that the change is being applied to.
  def find_and_save_audited_user
    if auditable.respond_to?(:user)
      self.audited_user = auditable.user
    elsif auditable.is_a?(User)
      self.audited_user = auditable
    end
    self.audited_username = audited_user&.name
  end

  def find_and_save_associated_rule
    return unless auditable_type == 'BaseRule' && associated_type == 'Component'

    # No auditing for hard deletes
    return if action == 'destroy'

    rule = Rule.find_by(id: auditable_id)
    self.audited_username = "Control #{rule&.displayed_name}" if rule.present? & rule.component.present?
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
          field: format_audited_field(audited_field),
          prev_value: (audited_value.is_a?(Array) ? audited_value[0] : nil),
          new_value: (audited_value.is_a?(Array) ? audited_value[1] : audited_value)
        }
      end
    }
  end

  private

  # AdditionalAnswers are a special case where the field value is not the field
  # that changed but rather the name of the associated additional_question.
  def format_audited_field(field)
    return auditable.additional_question.name if auditable_type.eql?('AdditionalAnswer') && field.eql?('answer')

    field
  end
end
