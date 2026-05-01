# frozen_string_literal: true

module Import
  module JsonArchive
    # Imports reviews from backup JSON. Resolves user by email; stores name
    # for attribution even if user not found on this system.
    # Uses direct INSERT to bypass Review model callbacks (same pattern
    # as Component#duplicate_reviews_and_history).
    #
    # PR #717: handles public-comment review lifecycle fields including reply
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
      def initialize(reviews_data, rule_id_map, result, component: nil, manifest: nil, imported_by: nil)
        @reviews_data = reviews_data
        @rule_id_map = rule_id_map
        @result = result
        @component = component
        @manifest = manifest
        @imported_by = imported_by
      end

      def build_all
        # Pass 1: insert every review, capture external_id → new DB id map
        external_to_new_id = {}
        count = 0
        @reviews_data.each do |review_data|
          rule_db_id = @rule_id_map[review_data['rule_id']]
          unless rule_db_id
            @result.add_warning("Review: rule_id '#{review_data['rule_id']}' not found in imported rules")
            next
          end

          user = resolve_user(review_data, 'user_email', 'user_name')
          unless user
            @result.add_warning(
              "Review: user '#{review_data['user_email'] || review_data['user_name']}' not found. " \
              "Review for rule #{review_data['rule_id']} skipped."
            )
            next
          end

          new_id = insert_review(review_data, rule_db_id, user)
          external_id = review_data['external_id']
          external_to_new_id[external_id] = new_id if external_id
          count += 1
        end

        # Pass 2: patch responding_to_review_id + duplicate_of_review_id using
        # the external_id → new_id map. Backups without these refs short-circuit.
        relink_threaded_refs(external_to_new_id)

        # PR-717 review remediation .9 — Review.insert! bypasses model
        # validators (duplicate_status_requires_target, responding_to_must_be_same_rule,
        # duplicate_of_must_be_same_component, inclusion validators on
        # triage_status / section). Re-load each inserted record and run
        # `valid?`; on failure, warn (with the archive's external_id +
        # validator messages) and delete the row to keep the post-import DB
        # clean. Children pointing at a removed parent cascade-delete via
        # the FK on_delete: :cascade we already have on responding_to_review_id.
        dropped = drop_invalid_reviews(external_to_new_id)

        # PR-717 review remediation .10 — write a Component-level audit row
        # listing imported external_ids + archive identifier. Recovery trail
        # for admin_destroy → re-import scenarios.
        write_import_audit(external_to_new_id)

        count - dropped
      end

      private

      def insert_review(review_data, rule_db_id, user)
        created_at = parse_time(review_data['created_at']) || Time.current
        attrs = {
          user_id: user.id,
          rule_id: rule_db_id,
          action: review_data['action'],
          comment: review_data['comment'],
          created_at: created_at,
          updated_at: created_at
        }
        attrs.merge!(lifecycle_attrs(review_data))

        # rubocop:disable Rails/SkipsModelValidations
        # Direct INSERT bypasses model callbacks (same pattern as
        # Component#duplicate_reviews_and_history). Required for restoring
        # historical reviews without re-firing the create-time gates.
        Review.insert!(attrs).rows.first.first
        # rubocop:enable Rails/SkipsModelValidations
      end

      def lifecycle_attrs(review_data)
        attrs = {}
        attrs[:section] = review_data['section'] if review_data.key?('section')
        attrs[:triage_status] = review_data['triage_status'] if review_data['triage_status'].present?
        attrs[:triage_set_at] = parse_time(review_data['triage_set_at']) if review_data['triage_set_at']
        attrs[:adjudicated_at] = parse_time(review_data['adjudicated_at']) if review_data['adjudicated_at']

        attrs.merge!(attribution_attrs(review_data, 'triage_set_by'))
        attrs.merge!(attribution_attrs(review_data, 'adjudicated_by'))

        attrs
      end

      # PR-717 review remediation .8 — if the user resolves on this instance,
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
        surviving_new_ids = Review.where(id: external_to_new_id.values).pluck(:id).to_set
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
        removed = 0
        Review.where(id: external_to_new_id.values).find_each do |review|
          # `:import_integrity` is a Rails custom validation context. Per
          # Rails Guides §7.3, calling valid?(:custom) runs (a) validators
          # tagged on: :custom AND (b) validators with no on: option;
          # validators tagged on: %i[create update] are skipped. Review's
          # user-action permission validators are tagged on: %i[create update]
          # so the import context runs ONLY data-integrity validators
          # (cross-rule references, status enums, FK invariants).
          next if review.valid?(:import_integrity)

          ext = new_id_to_external[review.id] || review.id
          @result.add_warning(
            "Review #{ext}: failed validation on import — " \
            "#{review.errors.full_messages.join('; ')}. Removed to preserve DB integrity."
          )
          # delete (not destroy) to skip after_destroy + audit-on-destroy.
          # The row was never user-facing on this instance — no audit-trail
          # value to preserve. FK on_delete: :cascade still removes children.
          review.delete
          removed += 1
        end
        removed
      end

      def relink_threaded_refs(external_to_new_id)
        return if external_to_new_id.empty?

        @reviews_data.each do |review_data|
          new_id = external_to_new_id[review_data['external_id']]
          next unless new_id

          updates = {}
          parent_external = review_data['responding_to_external_id']
          if parent_external && (mapped = external_to_new_id[parent_external])
            updates[:responding_to_review_id] = mapped
          end

          dup_external = review_data['duplicate_of_external_id']
          if dup_external && (mapped = external_to_new_id[dup_external])
            updates[:duplicate_of_review_id] = mapped
          end

          # rubocop:disable Rails/SkipsModelValidations
          Review.where(id: new_id).update_all(updates) if updates.any?
          # rubocop:enable Rails/SkipsModelValidations
        end
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
