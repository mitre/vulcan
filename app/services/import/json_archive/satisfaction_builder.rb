# frozen_string_literal: true

module Import
  module JsonArchive
    # Rebuilds rule_satisfactions from backup JSON using rule_id string → new DB ID mapping.
    class SatisfactionBuilder
      def initialize(satisfactions_data, rule_id_map, result)
        @satisfactions_data = satisfactions_data
        @rule_id_map = rule_id_map
        @result = result
      end

      def build_all
        count = 0
        @satisfactions_data.each do |sat_data|
          rule_db_id = @rule_id_map[sat_data['rule_id']]
          satisfied_by_db_id = @rule_id_map[sat_data['satisfied_by_rule_id']]

          unless rule_db_id
            @result.add_warning("Satisfaction: rule_id '#{sat_data['rule_id']}' not found in imported rules")
            next
          end

          unless satisfied_by_db_id
            @result.add_warning(
              "Satisfaction: satisfied_by_rule_id '#{sat_data['satisfied_by_rule_id']}' not found in imported rules"
            )
            next
          end

          # Check for existing satisfaction to avoid duplicates
          next if RuleSatisfaction.exists?(rule_id: rule_db_id, satisfied_by_rule_id: satisfied_by_db_id)

          RuleSatisfaction.create!(rule_id: rule_db_id, satisfied_by_rule_id: satisfied_by_db_id)
          count += 1
        end
        count
      end
    end
  end
end
