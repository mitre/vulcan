# frozen_string_literal: true

# The kind-aware component copy surface — shared by user duplicate, overlay
# (both via the amoeba customize step), and the release-copy path. Authored
# SrgRules cannot ride amoeba: the :rules association include is Rule-scoped,
# and SrgRule's own amoeba block deliberately retypes copies to Rule for the
# STIG import flow. BaseRule#dup_with_nested_records is the same-type copy
# primitive both kinds share.
module ComponentCopy
  extend ActiveSupport::Concern

  # Copies every live authored requirement onto an in-memory component copy
  # as an unsaved SrgRule with its nested records, applying the same resets
  # STIG copies get from Rule's amoeba block (unlocked, no review request,
  # no section locks). A no-op for stig components (the collection is
  # empty). The requirements: override lets release-copy pass its own
  # filtered scope through the same seam.
  def copy_authored_requirements_onto(new_component, requirements: authored_srg_rules)
    new_component.authored_srg_rules = requirements.map do |requirement|
      copy = requirement.dup_with_nested_records
      copy.locked = false
      copy.review_requestor_id = nil
      copy.locked_fields = {}
      copy
    end
  end

  # Copy audit history and reviews from the original component's
  # requirements to the duplicated component's requirements — both kinds
  # (reviews on authored SrgRules carry rule_id through the dual-write
  # callback, so the rule_id join below reaches them). Uses bulk SQL
  # (4 queries total) instead of per-row queries for dramatically better
  # performance.
  def duplicate_reviews_and_history(component_id)
    return unless component_id

    orig = Component.find(component_id)
    conn = ActiveRecord::Base.connection

    # Build rule_id → new requirement id mapping (matched by rule_id field)
    new_rows_by_rule_id = requirements.index_by(&:rule_id)
    id_map = orig.requirements.filter_map do |orig_row|
      new_row = new_rows_by_rule_id[orig_row.rule_id]
      [orig_row.id, new_row.id] if new_row
    end
    return if id_map.empty?

    new_ids = id_map.map(&:last)

    # Create a temporary mapping table for bulk operations. The ids travel as
    # two array bind parameters and unnest zips them back into rows, which keeps
    # every statement below a fixed string with no interpolation at all. A
    # VALUES list would need one placeholder pair per row, making the SQL text
    # vary with the row count and defeating statement caching.
    mapping_cte = 'rule_map AS (SELECT * FROM unnest($1::bigint[], $2::bigint[]) AS t(orig_id, new_id))'
    mapping_binds = [bigint_array_bind(id_map.map(&:first)), bigint_array_bind(id_map.map(&:last))]
    new_id_binds = [bigint_array_bind(new_ids)]

    # 1. Preserve original timestamps on duplicated requirements
    conn.exec_update(
      "WITH #{mapping_cte} UPDATE base_rules " \
      'SET created_at = orig.created_at, updated_at = orig.updated_at ' \
      'FROM rule_map JOIN base_rules orig ON orig.id = rule_map.orig_id ' \
      'WHERE base_rules.id = rule_map.new_id',
      'ComponentCopy Timestamps', mapping_binds
    )

    # 2. Remove auto-generated audits from the duplication save
    conn.exec_delete(
      "DELETE FROM audits WHERE auditable_type = 'BaseRule' " \
      'AND auditable_id = ANY($1::bigint[])',
      'ComponentCopy Audit Cleanup', new_id_binds
    )

    # 3. Copy original audit history to new requirements
    conn.exec_insert(
      "WITH #{mapping_cte} " \
      'INSERT INTO audits (auditable_id, auditable_type, associated_id, associated_type, ' \
      'user_id, user_type, username, action, audited_changes, version, ' \
      'comment, remote_address, request_uuid, created_at, audited_user_id, audited_username) ' \
      'SELECT rule_map.new_id, a.auditable_type, a.associated_id, a.associated_type, ' \
      'a.user_id, a.user_type, a.username, a.action, a.audited_changes, a.version, ' \
      'a.comment, a.remote_address, a.request_uuid, a.created_at, ' \
      'a.audited_user_id, a.audited_username FROM audits a ' \
      "JOIN rule_map ON a.auditable_id = rule_map.orig_id WHERE a.auditable_type = 'BaseRule'",
      'ComponentCopy Audits', mapping_binds
    )

    # 4. Copy reviews from original requirements. Dual-write the polymorphic
    # commentable target (BaseRule + new requirement id) — this raw INSERT
    # bypasses sync_commentable_from_rule, and the triage read paths filter
    # on commentable_*, so omitting them hides the copied comments.
    conn.exec_insert(
      "WITH #{mapping_cte} " \
      'INSERT INTO reviews (user_id, rule_id, commentable_type, commentable_id, ' \
      'action, comment, created_at, updated_at) ' \
      "SELECT r.user_id, rule_map.new_id, 'BaseRule', rule_map.new_id, " \
      'r.action, r.comment, r.created_at, r.updated_at ' \
      'FROM reviews r JOIN rule_map ON r.rule_id = rule_map.orig_id',
      'ComponentCopy Reviews', mapping_binds
    )
  end

  # Bind a list of ids as a single bigint[] query parameter. Integer() is kept
  # as the coercion so a non-numeric id still raises here rather than reaching
  # the database — to_i would silently turn bad input into 0.
  def bigint_array_bind(values)
    ActiveRecord::Relation::QueryAttribute.new(
      nil,
      values.map { |value| Integer(value) },
      ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Array.new(ActiveRecord::Type::BigInteger.new)
    )
  end
end
