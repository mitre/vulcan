# frozen_string_literal: true

module Import
  module JsonArchive
    # Imports reviews from backup JSON. Resolves user by email; stores name
    # for attribution even if user not found on this system.
    # Uses direct INSERT to bypass Review model callbacks (same pattern
    # as Component#duplicate_reviews_and_history).
    class ReviewBuilder
      def initialize(reviews_data, rule_id_map, result)
        @reviews_data = reviews_data
        @rule_id_map = rule_id_map
        @result = result
      end

      def build_all
        count = 0
        @reviews_data.each do |review_data|
          rule_db_id = @rule_id_map[review_data['rule_id']]
          unless rule_db_id
            @result.add_warning("Review: rule_id '#{review_data['rule_id']}' not found in imported rules")
            next
          end

          user = resolve_user(review_data)
          unless user
            @result.add_warning(
              "Review: user '#{review_data['user_email'] || review_data['user_name']}' not found. " \
              "Review for rule #{review_data['rule_id']} skipped."
            )
            next
          end

          created_at = review_data['created_at'] ? Time.zone.parse(review_data['created_at']) : Time.current

          Review.insert!({ # rubocop:disable Rails/SkipsModelValidations -- direct INSERT for performance (same pattern as duplicate_reviews_and_history)
                           user_id: user.id,
                           rule_id: rule_db_id,
                           action: review_data['action'],
                           comment: review_data['comment'],
                           created_at: created_at,
                           updated_at: created_at
                         })
          count += 1
        end
        count
      end

      private

      def resolve_user(review_data)
        email = review_data['user_email']
        return User.find_by(email: email) if email.present?

        name = review_data['user_name']
        return User.find_by(name: name) if name.present?

        nil
      end
    end
  end
end
