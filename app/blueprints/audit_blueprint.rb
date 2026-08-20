# frozen_string_literal: true

# Serializes Audited::Audit records, replacing VulcanAudit#format.
# Produces the same shape Vue's History.vue expects: id, action,
# auditable_type/id, name, audited_name, comment, created_at,
# and audited_changes as [{field, prev_value, new_value}].
class AuditBlueprint < Blueprinter::Base
  identifier :id

  fields :action, :auditable_type, :auditable_id, :comment

  field :name do |audit, _options|
    audit.username
  end

  field :audited_name do |audit, _options|
    audit.audited_username
  end

  field :created_at do |audit, _options|
    audit.created_at
  end

  field :audited_changes do |audit, _options|
    audit.audited_changes.map do |audited_field, audited_value|
      field_name = if audit.auditable_type == 'AdditionalAnswer' && audited_field == 'answer'
                     audit.auditable&.additional_question&.name || audited_field
                   else
                     audited_field
                   end

      {
        'field' => field_name,
        'prev_value' => (audited_value.is_a?(Array) ? audited_value[0] : nil),
        'new_value' => (audited_value.is_a?(Array) ? audited_value[1] : audited_value)
      }
    end
  end
end
