# frozen_string_literal: true

# F4 forensic correlation primitive.
#
# Wraps the `request_uuid` indexed query so reconstructing a multi-row
# admin operation (e.g. admin_destroy of a parent comment cascading N
# replies) is one ergonomic call rather than ad-hoc queries at every
# call site.
#
# Audited gem auto-populates `request_uuid` (`Audited::Sweeper` Rack
# middleware) so every audit row created during one HTTP request shares
# one UUID. Out-of-request audit rows (rake tasks, seeds, direct
# ReviewBuilder calls) carry NULL request_uuid — `#related` returns
# only the trigger row in that case.
#
# Reach via `Audited::Audit.bundled_with(audit_id)` rather than
# constructing directly.
class AuditEventBundle
  attr_reader :trigger

  def initialize(trigger_audit)
    @trigger = trigger_audit
  end

  # Every audit row sharing the trigger's request_uuid (includes the
  # trigger itself). Returns just [trigger] when request_uuid is nil
  # (out-of-request audit creation).
  def related
    @related ||= if @trigger.request_uuid.present?
                   VulcanAudit.where(request_uuid: @trigger.request_uuid).to_a
                 else
                   [@trigger]
                 end
  end

  # The Review-destroy events from the bundle. Forensic surface for
  # "what got hard-deleted in this admin operation" — pair with the
  # trigger's audited_changes['destroyed_review_snapshots'] for the
  # full pre-destroy state of every affected row.
  def destroyed_reviews
    related.select { |a| a.action == 'destroy' && a.auditable_type == 'Review' }
  end

  def destroyed_review_count
    destroyed_reviews.size
  end

  # Compact JSON-serializable summary. Useful for forensic tooling /
  # admin UIs / API responses.
  def to_h
    {
      trigger_id: @trigger.id,
      request_uuid: @trigger.request_uuid,
      related_count: related.size,
      destroyed_review_ids: destroyed_reviews.map(&:auditable_id)
    }
  end
end
