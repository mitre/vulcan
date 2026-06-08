# frozen_string_literal: true

module Import
  module JsonArchive
    # Imports reviews from backup JSON. Resolves user by email; stores name
    # for attribution even if user not found on this system.
    # Uses direct INSERT to bypass Review model callbacks (same pattern
    # as Component#duplicate_reviews_and_history).
    #
    # handles public-comment review lifecycle fields including reply
    # threading + duplicate cross-links. Uses a two-pass approach so the new
    # DB ids assigned at import time can be mapped to the original external_ids
    # in the archive — pass 1 inserts every review without parent/dup refs,
    # pass 2 patches parent/dup using the external_id → new_id map.
    class ReviewBuilder
      # `component`, `manifest`, and `imported_by` are optional kwargs so
      # legacy/test callers can still construct ReviewBuilder positionally.
      # When all three are present, `build_all` writes a Component-level
      # audit row capturing WHICH external_ids landed FROM WHICH archive
      # — closes the audit-laundering chain documented in PR-717 review
      # remediation .10 (admin_destroy → re-import via Review.insert!
      # bypasses audited; the Component-level row preserves the recovery
      # trail).
      #
      # external_to_new_id is populated during build_all and exposed to
      # callers (Applier) that need per-row audit linkage between the
      # archive's external_id and the actual new Review.id.
      attr_reader :external_to_new_id

      def initialize(reviews_data, rule_id_map, result, component: nil, manifest: nil, imported_by: nil)
        @reviews_data = reviews_data
        @rule_id_map = rule_id_map
        @result = result
        @component = component
        @manifest = manifest
        @imported_by = imported_by
        @external_to_new_id = {}
      end

      def build_all
        # defensive transaction
        # wrap. JsonArchiveImporter#perform_import wraps in an outer
        # ActiveRecord::Base.transaction for the production path; this inner
        # txn becomes a savepoint there. For direct/test callers
        # (constructor explicitly supports them per `:24` "legacy/test
        # callers"), the inner txn ensures pass-1 inserts roll back if
        # pass 2 (relink) or pass 3 (drop_invalid + audit) raises.
        Review.transaction do
          # Pass 1: insert every review, capture external_id → new DB id map
          count = 0
          @reviews_data.each do |review_data|
            rule_db_id = @rule_id_map[review_data['rule_id']]
            unless rule_db_id
              @result.add_warning("Review: rule_id '#{review_data['rule_id']}' not found in imported rules")
              next
            end

            commenter = commenter_attrs(review_data)
            next if commenter.nil?

            new_id = insert_review(review_data, rule_db_id, commenter)
            external_id = review_data['external_id']
            @external_to_new_id[external_id] = new_id if external_id
            count += 1
          end

          # Pass 2: patch responding_to_review_id + duplicate_of_review_id using
          # the external_id → new_id map. Backups without these refs short-circuit.
          relink_threaded_refs(@external_to_new_id)

          # Review.insert! bypasses model
          # validators. Re-load each inserted record and run `valid?`; on
          # failure, warn + delete the row. Children of removed parents
          # cascade-delete via the FK semantics on responding_to_review_id.
          dropped = drop_invalid_reviews(@external_to_new_id)

          # Defensive net: insert_review dual-writes commentable, but guard
          # against any future insert!/raw-SQL path that forgets it so the
          # triage read paths never silently hide imported comments.
          Review.where(id: @external_to_new_id.values).repair_missing_commentable!

          # write a Component-level audit row
          # listing imported external_ids + archive identifier. Recovery
          # trail for admin_destroy → re-import scenarios.
          write_import_audit(@external_to_new_id)

          count - dropped
        end
      end

      private

      def insert_review(review_data, rule_db_id, commenter)
        created_at = parse_time(review_data['created_at']) || Time.current
        attrs = {
          rule_id: rule_db_id,
          # Dual-write the polymorphic target. insert! skips
          # sync_commentable_from_rule, and the triage read paths filter on
          # commentable_type/commentable_id — without these the imported
          # comments are counted but never listed.
          commentable_type: 'BaseRule',
          commentable_id: rule_db_id,
          action: review_data['action'],
          comment: review_data['comment'],
          created_at: created_at,
          updated_at: created_at
        }
        attrs.merge!(commenter)
        attrs.merge!(lifecycle_attrs(review_data))
        attrs.merge!(provenance_attrs(review_data))

        # rubocop:disable Rails/SkipsModelValidations
        # Direct INSERT bypasses model callbacks (same pattern as
        # Component#duplicate_reviews_and_history). Required for restoring
        # historical reviews without re-firing the create-time gates.
        Review.insert!(attrs).rows.first.first
        # rubocop:enable Rails/SkipsModelValidations
      end

      # return one of:
      # - { user_id: <id> } when the commenter resolves to a User
      # - { user_id: nil, commenter_imported_email/name: ... } when
      #   email or name carry forward but no User matches on this instance
      # - nil when neither attribution nor User exists (caller should skip)
      def commenter_attrs(review_data)
        user = resolve_user(review_data, 'user_email', 'user_name')
        return { user_id: user.id } if user

        email = review_data['user_email']
        name = review_data['user_name']
        if email.blank? && name.blank?
          @result.add_warning(
            "Review #{review_data['external_id']}: no commenter attribution (user_email + user_name " \
            'both blank). Cannot import — skipping.'
          )
          return nil
        end

        @result.add_warning(
          "Review #{review_data['external_id']}: commenter '#{email || name}' not found on this instance — " \
          'original attribution preserved on commenter_imported_email/name (no FK).'
        )
        {
          user_id: nil,
          commenter_imported_email: email,
          commenter_imported_name: name
        }
      end

      def lifecycle_attrs(review_data)
        attrs = {}
        attrs[:section] = review_data['section'] if review_data.key?('section')
        attrs[:triage_status] = review_data['triage_status'] if review_data['triage_status'].present?
        # insert! bypasses Review#default_triage_status_for_new_top_level_comment,
        # so apply the same default here: an untriaged top-level comment is
        # 'pending'. Replies (responding_to_external_id present) must stay NULL.
        if attrs[:triage_status].blank? &&
           review_data['action'] == Review::ACTION_COMMENT &&
           review_data['responding_to_external_id'].blank?
          attrs[:triage_status] = 'pending'
        end
        attrs[:triage_set_at] = parse_time(review_data['triage_set_at']) if review_data['triage_set_at']
        attrs[:adjudicated_at] = parse_time(review_data['adjudicated_at']) if review_data['adjudicated_at']

        # Cross-instance FK remap: archive carries the stable rule_id string;
        # look up the new local BaseRule.id via rule_id_map. If the addressing
        # rule isn't in the archive, leave nil — addressed_by_status_requires_rule
        # will drop the row via drop_invalid_reviews with an actionable warning.
        if review_data['addressed_by_rule_id'].present?
          mapped = @rule_id_map[review_data['addressed_by_rule_id']]
          attrs[:addressed_by_rule_id] = mapped if mapped
        end

        attrs.merge!(attribution_attrs(review_data, 'triage_set_by'))
        attrs.merge!(attribution_attrs(review_data, 'adjudicated_by'))

        attrs
      end

      # if the user resolves on this instance,
      # set the FK as today. If the user can't resolve but the archive has
      # an email or name (i.e. attribution data exists), preserve it on
      # imported_email/imported_name columns and record a warning so the
      # operator sees who-triaged-what was preserved-but-unmapped. Display +
      # export layers fall back to the imported_* columns when FK is nil.
      def attribution_attrs(review_data, role_prefix)
        email = review_data["#{role_prefix}_email"]
        name = review_data["#{role_prefix}_name"]
        user = resolve_user(review_data, "#{role_prefix}_email", "#{role_prefix}_name")
        return { "#{role_prefix}_id": user.id } if user
        return {} if email.blank? && name.blank?

        @result.add_warning(
          "Review #{review_data['external_id']}: #{role_prefix} '#{email || name}' not found on this " \
          'instance — original attribution preserved on imported_email/imported_name (no FK).'
        )
        {
          "#{role_prefix}_imported_email": email,
          "#{role_prefix}_imported_name": name
        }
      end

      def write_import_audit(external_to_new_id)
        return unless @component && @manifest
        return if external_to_new_id.empty?

        # Filter to external_ids whose new_id still exists in the DB after
        # the drop-invalid pass — preserves the "WHICH external_ids landed"
        # semantic (an external_id whose row was dropped is not a recovery
        # trail entry).
        surviving_new_ids = Review.where(id: external_to_new_id.values).ids.to_set
        landed_external_ids = external_to_new_id.select { |_ext, new_id| surviving_new_ids.include?(new_id) }.keys
        return if landed_external_ids.empty?

        @component.audits.create!(
          user: @imported_by,
          action: 'import_reviews',
          audited_changes: {
            'archive_vulcan_version' => @manifest['vulcan_version'],
            'archive_exported_at' => @manifest['exported_at'],
            'review_external_ids' => landed_external_ids
          },
          comment: "Imported #{landed_external_ids.size} reviews from backup archive " \
                   "(vulcan_version=#{@manifest['vulcan_version']}, exported_at=#{@manifest['exported_at']})"
        )
      end

      def drop_invalid_reviews(external_to_new_id)
        return 0 if external_to_new_id.empty?

        new_id_to_external = external_to_new_id.invert
        invalid_ids = []
        Review.where(id: external_to_new_id.values).find_each do |review|
          next if review.valid?(:import_integrity)

          ext = new_id_to_external[review.id] || review.id
          @result.add_warning(
            "Review #{ext}: failed validation on import — " \
            "#{review.errors.full_messages.join('; ')}. Removed to preserve DB integrity."
          )
          invalid_ids << review.id
        end

        return 0 if invalid_ids.empty?

        # Delete children before parents to respect FK RESTRICT on
        # responding_to_review_id. Collect the full tree of descendants
        # then delete leaves-first.
        all_ids_to_delete = Set.new(invalid_ids)
        queue = invalid_ids.dup
        until queue.empty?
          child_ids = Review.where(responding_to_review_id: queue).pluck(:id)
          new_children = child_ids.reject { |id| all_ids_to_delete.include?(id) }
          all_ids_to_delete.merge(new_children)
          queue = new_children
        end

        # Topological delete: deepest children first
        remaining = all_ids_to_delete.to_a
        until remaining.empty?
          parents_of_remaining = Review.where(responding_to_review_id: remaining)
                                       .where(id: remaining).pluck(:responding_to_review_id)
          leaves = remaining.reject { |id| parents_of_remaining.include?(id) }
          leaves = remaining if leaves.empty?
          Review.where(id: leaves).delete_all
          remaining -= leaves
        end

        all_ids_to_delete.size
      end

      def relink_threaded_refs(external_to_new_id)
        return if external_to_new_id.empty?

        responding = {}
        duplicate = {}
        @reviews_data.each do |review_data|
          new_id = external_to_new_id[review_data['external_id']]
          next unless new_id

          if (parent_external = review_data['responding_to_external_id']) &&
             (mapped = external_to_new_id[parent_external])
            responding[new_id] = mapped
          end

          if (dup_external = review_data['duplicate_of_external_id']) &&
             (mapped = external_to_new_id[dup_external])
            duplicate[new_id] = mapped
          end
        end

        bulk_relink(responding, duplicate)
      end

      # Single CASE-based UPDATE per affected column.
      # Replaces an N+1 of per-review update_all calls. All interpolated values
      # are Integer()-cast PKs (matches the existing Brakeman-ignored pattern
      # in Component#duplicate_reviews_and_history).
      def bulk_relink(responding, duplicate)
        return if responding.empty? && duplicate.empty?

        ids = (responding.keys + duplicate.keys).uniq.map { |i| Integer(i) }
        sets = []
        sets << case_set('responding_to_review_id', responding) if responding.any?
        sets << case_set('duplicate_of_review_id',  duplicate)  if duplicate.any?

        Review.connection.exec_update(
          "UPDATE reviews SET #{sets.join(', ')} WHERE id IN (#{ids.join(', ')})"
        )
      end

      def case_set(column, mapping)
        whens = mapping.map { |k, v| "WHEN #{Integer(k)} THEN #{Integer(v)}" }.join(' ')
        "#{column} = CASE id #{whens} ELSE #{column} END"
      end

      def provenance_attrs(review_data)
        original_rule_id_str = review_data['original_rule_id']
        return {} if original_rule_id_str.blank?

        original_db_id = @rule_id_map[original_rule_id_str]
        return {} unless original_db_id

        { original_commentable_id: original_db_id }
      end

      def parse_time(raw)
        return nil if raw.blank?

        Time.zone.parse(raw.to_s)
      rescue ArgumentError
        nil
      end

      def resolve_user(review_data, email_key, name_key)
        email = review_data[email_key]
        return User.find_by(email: email) if email.present?

        name = review_data[name_key]
        return User.find_by(name: name) if name.present?

        nil
      end
    end
  end
end
