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
      def initialize(reviews_data, rule_id_map, result)
        @reviews_data = reviews_data
        @rule_id_map = rule_id_map
        @result = result
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

        count
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

        triager = resolve_user(review_data, 'triage_set_by_email', 'triage_set_by_name')
        attrs[:triage_set_by_id] = triager.id if triager

        adjudicator = resolve_user(review_data, 'adjudicated_by_email', 'adjudicated_by_name')
        attrs[:adjudicated_by_id] = adjudicator.id if adjudicator

        attrs
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
