# frozen_string_literal: true

# Custom Audited class for Vulcan-specific methods for interacting with audits.
class VulcanAudit < Audited::Audit
  belongs_to :audited_user, class_name: 'User', optional: true
  # PR-717 review remediation .14r — request_uuid invariant. The audited
  # gem's Audited::Sweeper Rack middleware sets request_uuid for HTTP
  # requests; recent versions also fall back to SecureRandom for
  # non-HTTP contexts. This callback makes the invariant a Vulcan-side
  # guarantee (independent of gem version): every audit row has a
  # request_uuid. For job/rake-task contexts that want to share a UUID
  # across multiple audit rows in one logical operation, set
  # Audited.store[:current_request_uuid] before triggering the audited
  # operations; this callback reads it first.
  #
  # Order matters: ensure_request_uuid runs FIRST so other callbacks
  # observing the value see the populated UUID. ||= preserves any value
  # already set by Audited::Sweeper (HTTP path).
  before_create :ensure_request_uuid,
                :set_username, :find_and_save_audited_user, :find_and_save_associated_rule

  # PR-717 review remediation .4 — F4 forensic correlation primitive.
  # Wraps the request_uuid indexed query in an AuditEventBundle PORO so
  # forensic reconstruction of multi-row admin operations (admin_destroy
  # of parent + cascaded replies) is one ergonomic call.
  # See app/services/audit_event_bundle.rb for the bundle interface.
  def self.bundled_with(audit_id)
    AuditEventBundle.new(find(audit_id))
  end

  # PR-717 review remediation .vb4 — request_uuid PRODUCER side. Pairs
  # with the .14r consumer hook (#ensure_request_uuid before_create)
  # which reads Audited.store[:current_request_uuid]. Bulk audit-emitting
  # code paths outside an HTTP request (rake tasks, importers, future
  # ActiveJob workers) wrap their work in this scope so every audit row
  # created during the block shares one request_uuid — matching the
  # in-request behavior provided by Audited::Sweeper Rack middleware.
  #
  # Snapshot+restore (not set+delete) so it nests correctly under any
  # outer scope that already set the value (e.g. an HTTP request that
  # invokes a service object).
  def self.with_correlation_scope(uuid: SecureRandom.uuid)
    prev = Audited.store[:current_request_uuid]
    Audited.store[:current_request_uuid] = uuid
    yield uuid
  ensure
    Audited.store[:current_request_uuid] = prev
  end

  def self.create_initial_rule_audit_from_mapping(project_id)
    {
      auditable_type: 'Rule',
      action: 'create',
      user_type: 'System',
      audited_changes: {
        project_id: project_id
      },
      # PR-717 review remediation .vb4 — populate request_uuid at build
      # time too. This row will be persisted via activerecord-import's
      # bulk path (Component#import_srg_rules → Rule.import recursive:
      # true), which BYPASSES ActiveRecord callbacks. Without this the
      # ensure_request_uuid before_create hook never fires, leaving the
      # row with NULL request_uuid even when it sits inside a
      # with_correlation_scope. Reading current_request_uuid here
      # guarantees the bulk-inserted audits share the scope UUID
      # (or get a fresh SecureRandom orphan UUID if no scope is set).
      request_uuid: current_request_uuid
    }
  end

  # PR-717 review remediation .vb4 — single source of truth for
  # "what request_uuid should this audit have right now". Used by
  # both the consumer-side before_create hook (#ensure_request_uuid)
  # and bulk-insert build paths that bypass callbacks (e.g.
  # create_initial_rule_audit_from_mapping). Inside a
  # with_correlation_scope block returns the scope UUID; outside one
  # returns a fresh SecureRandom UUID (orphan path).
  def self.current_request_uuid
    Audited.store[:current_request_uuid] || SecureRandom.uuid
  end

  def ensure_request_uuid
    self.request_uuid ||= self.class.current_request_uuid
  end

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
    # Use `&&` (short-circuit) not `&` (bitwise). `&` evaluates both sides, so
    # `rule.component.present?` would blow up on NoMethodError when rule is nil.
    return unless rule&.component

    self.audited_username = "Control #{rule.displayed_name}"
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
