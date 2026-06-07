# frozen_string_literal: true

module Import
  module JsonArchive
    module Merge
      # Same contract as RuleFieldDiffer (hash comparison, locked-section
      # check, Strategy verb mapping) but iterates over the columns of
      # rule-associated records (Check, DisaRuleDescription) per the
      # Rule::NESTED_MERGEABLE_ASSOCIATIONS schema.
      #
      # Without this, locking the 'Check' section silently fails to enforce
      # on Check#content edits because RuleFieldDiffer only sees rule
      # columns. Same F14 guarantee holds: no assign_attributes, no
      # callbacks fire — pure hash comparison.
      class NestedAssociationDiffer
        # Reuse the rule-level types so MergePlan partitioning works uniformly.
        FieldChange = RuleFieldDiffer::FieldChange
        STRATEGY_VERB_MAP = RuleFieldDiffer::STRATEGY_VERB_MAP

        def initialize(ours_rule:, theirs_rule_hash:, strategy:)
          @ours_rule = ours_rule
          @theirs_rule_hash = theirs_rule_hash
          @strategy = strategy
          @locked_sections = (ours_rule.locked_fields || {}).keys.to_set
        end

        def diff
          changes = []
          Rule::NESTED_MERGEABLE_ASSOCIATIONS.each do |assoc_name, config|
            diff_association_into(changes, assoc_name, config)
          end
          changes
        end

        private

        def diff_association_into(changes, assoc_name, config)
          ours_records = ours_records_for(assoc_name)
          theirs_records = Array(@theirs_rule_hash[config[:backup_key]])

          pairs = pair_records(ours_records, theirs_records, config[:identity_keys])

          pairs.each do |ours_rec, theirs_rec|
            next if ours_rec.nil? || theirs_rec.nil? # only diff matched pairs in Phase 1

            diff_record_into(changes, ours_rec, theirs_rec, config[:fields_by_section])
          end
        end

        def ours_records_for(assoc_name)
          @ours_rule.public_send(assoc_name).to_a
        end

        # Pair up ours and theirs records. If identity_keys are provided,
        # build a composite key from them and match by it. Otherwise pair
        # positionally — the common case for 1-per-rule associations.
        def pair_records(ours_records, theirs_records, identity_keys)
          return positional_pairs(ours_records, theirs_records) if identity_keys.nil?

          ours_indexed = index_by_identity(ours_records, identity_keys, :ar)
          theirs_indexed = index_by_identity(theirs_records, identity_keys, :hash)

          (ours_indexed.keys | theirs_indexed.keys).map do |key|
            [ours_indexed[key], theirs_indexed[key]]
          end
        end

        def positional_pairs(ours_records, theirs_records)
          Array.new([ours_records.size, theirs_records.size].max) do |i|
            [ours_records[i], theirs_records[i]]
          end
        end

        def index_by_identity(records, identity_keys, kind)
          records.to_h do |rec|
            key = identity_keys.map { |k| kind == :ar ? rec.public_send(k) : rec[k] }.join('::')
            [key, rec]
          end
        end

        def diff_record_into(changes, ours_rec, theirs_rec, fields_by_section)
          fields_by_section.each do |section, fields|
            fields.each do |field|
              ours_val = ours_rec.attributes[field]
              theirs_val = theirs_rec[field]
              next if values_equal?(ours_val, theirs_val)

              changes << build_change(field, section, ours_val, theirs_val)
            end
          end
        end

        def values_equal?(ours, theirs)
          return true if ours == theirs
          return true if ours.nil? && theirs.respond_to?(:empty?) && theirs.empty?
          return true if theirs.nil? && ours.respond_to?(:empty?) && ours.empty?

          false
        end

        def build_change(field, section, ours_val, theirs_val)
          if @locked_sections.include?(section)
            FieldChange.new(
              field: field, from: ours_val, to: theirs_val,
              resolution: :locked_conflict, locked: true,
              reason: "Field '#{field}' is locked (section '#{section}') on the receiving component"
            )
          else
            verb = @strategy.for_field(:rule, field)
            FieldChange.new(
              field: field, from: ours_val, to: theirs_val,
              resolution: STRATEGY_VERB_MAP.fetch(verb, :conflict),
              locked: false,
              reason: "Strategy resolved to #{verb.inspect} (nested: #{section})"
            )
          end
        end
      end
    end
  end
end
