# frozen_string_literal: true

# This is the base model for the application. Things should only be
# placed here if they are shared between multiple models
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  ##
  # Build a structure that minimally describes the editing history of a model
  # and describes what can be reverted for that model.
  #
  # If `limit` is `nil`, then no limit will be applied on the number of histories returned
  #
  def histories(limit = 20)
    return unless defined?(own_and_associated_audits)

    own_and_associated_audits.order(:created_at).limit(limit).map do |audit|
      # Each audit can encompass multiple changes on the model (see audited_changes)
      {
        id: audit.id,
        action: audit.action,
        auditable_type: audit.auditable_type,
        auditable_id: audit.auditable_id,
        name: audit.user&.name || 'Unknown User',
        created_at: audit.created_at,
        audited_changes: audit.audited_changes.map do |audited_field, audited_value|
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
end
