# frozen_string_literal: true

module Import
  module JsonArchive
    module Merge
      # Raised when the analyzer detects a precondition violation that
      # makes the merge unsafe or undefined to proceed with. Phase 2c
      # (card .9) controller adds `rescue_from PreconditionError → 422`
      # per expert review F15; raw default would surface as 500.
      class PreconditionError < StandardError; end

      # Pure-computation entry point for the merge engine. Takes a
      # MergeInput and the receiving Component, returns a MergePlan
      # ready to hand to MergeApplier (Phase 2 card .8).
      #
      # No DB writes. Eager-loads what it needs to diff but never mutates.
      # Preconditions raise PreconditionError; structural defects (cycles,
      # partition violations) raise the analyzer's own error classes so
      # callers can distinguish "I won't" from "I can't."
      class Analyzer
        # Receiving component must be closed to comments — concurrent
        # writes are not safe while a merge analysis is computed.
        COMMENT_PHASE_REQUIRED = 'closed'

        # Pure-Ruby matcher is comfortable up to ~10K reviews; beyond
        # that callers should drop into the SQL-staging path (deferred
        # to Phase 2c). Sized to leave headroom below typical Postgres
        # statement-timeout settings. Counted as inbound + receiving so
        # the matcher's worst-case Hash allocation is bounded.
        REVIEW_CEILING = 10_000
        # Companion ceilings — same defense-in-depth
        # rationale, scaled to realistic STIG/component sizes.
        RULES_CEILING = 50_000
        SATISFACTIONS_CEILING = 50_000
        MEMBERSHIPS_CEILING = 10_000

        # Clock skew tolerance for archive created_at sanity check.
        FUTURE_TIMESTAMP_TOLERANCE = 1.day

        def initialize(merge_input:, component:, strategy: Strategy.new, manifest: nil)
          @merge_input = merge_input
          @component = component
          @strategy = strategy
          @manifest = manifest || merge_input.manifest
        end

        def call
          validate_preconditions!

          plan = MergePlan.new(
            component_id: @component.id,
            strategy: @strategy,
            manifest: @manifest
          )

          diff_rules_into(plan)
          match_reviews_into(plan)
          diff_satisfactions_into(plan)
          diff_memberships_into(plan)

          plan
        end

        private

        # Analysis-time preconditions only check things the analyzer itself
        # could trip over (memory, read-time data integrity). The
        # comment_phase == 'closed' guarantee is intent-coupled — it only
        # matters when actually writing — so it lives on the applier
        # (Phase 2), NOT here. sync:preview is a read-only
        # delta and must work regardless of phase.
        def validate_preconditions!
          require_review_ceiling!
          require_rules_ceiling!
          require_satisfactions_ceiling!
          require_memberships_ceiling!
          require_no_self_referencing_reviews! # F17 — before cycle DFS
          require_acyclic_reply_chains!
          require_no_future_timestamps!
        end

        def require_review_ceiling!
          # Total = inbound (archive) + receiving (live component). The
          # matcher allocates a Hash entry for both sides; the ceiling
          # must bound the actual memory footprint.
          inbound = @merge_input.reviews.size
          receiving = @component.is_a?(Component) ? @component.rules.joins(:reviews).count : 0
          total = inbound + receiving
          return if total <= REVIEW_CEILING

          raise PreconditionError,
                "reviews.size (inbound=#{inbound}, receiving=#{receiving}, total=#{total}) " \
                "exceeds Phase 1 ceiling of #{REVIEW_CEILING} — use the SQL-staging path (Phase 2c)"
        end

        def require_rules_ceiling!
          count = @merge_input.rules.size
          return if count <= RULES_CEILING

          raise PreconditionError,
                "rules.size (#{count}) exceeds ceiling of #{RULES_CEILING} — archive too large"
        end

        def require_satisfactions_ceiling!
          count = @merge_input.satisfactions.size
          return if count <= SATISFACTIONS_CEILING

          raise PreconditionError,
                "satisfactions.size (#{count}) exceeds ceiling of #{SATISFACTIONS_CEILING} — archive too large"
        end

        def require_memberships_ceiling!
          count = Array(@merge_input.memberships).size
          return if count <= MEMBERSHIPS_CEILING

          raise PreconditionError,
                "memberships.size (#{count}) exceeds ceiling of #{MEMBERSHIPS_CEILING} — archive too large"
        end

        # F17 CRITICAL: a review whose responding_to_external_id equals its
        # own external_id would infinite-loop the cycle DFS. Catch it here.
        def require_no_self_referencing_reviews!
          self_refs = @merge_input.reviews.select do |r|
            ext = r['external_id']
            ext && r['responding_to_external_id'] == ext
          end
          return if self_refs.empty?

          raise PreconditionError,
                "self-referencing review(s) detected: #{self_refs.pluck('external_id').inspect}"
        end

        # DFS over the responding_to_external_id graph. Self-refs are
        # already filtered out above; this catches honest cycles
        # (A→B, B→A or longer).
        def require_acyclic_reply_chains!
          edges = @merge_input.reviews.each_with_object({}) do |r, acc|
            ext = r['external_id']
            parent = r['responding_to_external_id']
            acc[ext] = parent if ext && parent
          end

          edges.each_key { |start| detect_cycle_from!(start, edges) }
        end

        def detect_cycle_from!(start, edges)
          slow = start
          fast = start
          loop do
            slow = edges[slow]
            fast = edges[edges[fast]] if edges[fast]
            return if slow.nil? || fast.nil?
            next unless slow == fast

            raise PreconditionError,
                  "cycle detected in responding_to chain (starts at external_id=#{start.inspect})"
          end
        end

        # F17 WARNING: timezone-aware check. Parse the archive timestamp
        # and compare against `Time.current + tolerance` — anything past
        # that is clock skew or a malicious archive.
        def require_no_future_timestamps!
          horizon = Time.current + FUTURE_TIMESTAMP_TOLERANCE
          bad = @merge_input.reviews.find do |r|
            stamp = r['created_at']
            stamp.present? && Time.zone.parse(stamp.to_s) > horizon
          end
          return if bad.nil?

          raise PreconditionError,
                "review.created_at #{bad['created_at']} is more than #{FUTURE_TIMESTAMP_TOLERANCE.inspect} " \
                'in the future — likely clock skew or tampered archive'
        end

        # Reuse the canonical backup eager-load list so the
        # NestedAssociationDiffer walks checks / disa_rule_descriptions
        # without N+1ing. Skip when the component is a duck-typed adapter
        # (VirtualComponent) — its rules are already in-memory hashes.
        def ours_rules_eager_loaded
          return @component.rules unless @component.is_a?(Component)

          @ours_rules_eager_loaded ||= @component.rules.includes(
            Export::Modes::Backup.new.eager_load_associations
          )
        end

        def diff_rules_into(plan)
          ours_by_id = ours_rules_eager_loaded.index_by(&:rule_id)
          theirs_by_id = @merge_input.rules.index_by { |r| r['rule_id'] }

          matched = []
          only_ours = []
          only_theirs = []

          (ours_by_id.keys | theirs_by_id.keys).each do |rule_id|
            ours_rule = ours_by_id[rule_id]
            theirs_hash = theirs_by_id[rule_id]

            if ours_rule && theirs_hash
              matched << rule_id
              field_changes = RuleFieldDiffer.new(
                ours_rule: ours_rule, theirs_rule_hash: theirs_hash, strategy: @strategy
              ).diff
              nested_differ = NestedAssociationDiffer.new(
                ours_rule: ours_rule, theirs_rule_hash: theirs_hash, strategy: @strategy
              )
              nested_changes = nested_differ.diff
              plan.add_field_changes(rule_id, field_changes + nested_changes)
              record_nested_one_sided(plan, rule_id, nested_differ.one_sided_records)
            elsif ours_rule
              only_ours << rule_id
            else
              # Store the full theirs hash (was: just rule_id string) so the
              # Applier can hand it to RuleBuilder verbatim. Mirrors how
              # reviews/satisfactions/memberships partition full records.
              only_theirs << theirs_hash
            end
          end

          plan.add_rule_partition(matched: matched, only_ours: only_ours, only_theirs: only_theirs)
          plan.validate_partition_invariant!(:rules, ours_count: ours_by_id.size, theirs_count: theirs_by_id.size)
        end

        def match_reviews_into(plan)
          ours_reviews = ours_rules_eager_loaded.flat_map do |rule|
            rule.reviews.map { |r| review_to_hash(r, rule.rule_id) }
          end
          theirs_reviews = @merge_input.reviews

          matcher = ReviewMatcher.new(
            ours_reviews: ours_reviews,
            theirs_reviews: theirs_reviews,
            manifest_version: @manifest['backup_format_version']
          )
          result = matcher.match

          plan.add_review_partition(
            matched: result.matched, only_ours: result.only_ours, only_theirs: result.only_theirs
          )
          plan.add_review_collisions(result.collisions)
          plan.validate_partition_invariant!(:reviews,
                                             ours_count: ours_reviews.size, theirs_count: theirs_reviews.size)
        end

        def diff_satisfactions_into(plan)
          ours_sat = ours_rules_eager_loaded.flat_map do |rule|
            rule.satisfies.map { |satisfied| { 'rule_id' => satisfied.rule_id, 'satisfied_by_rule_id' => rule.rule_id } }
          end
          theirs_sat = @merge_input.satisfactions.map { |s| s.is_a?(Hash) ? s : s.to_h }

          ours_by_key = ours_sat.index_by { |s| sat_key(s) }
          theirs_by_key = theirs_sat.index_by { |s| sat_key(s) }

          matched_keys = ours_by_key.keys & theirs_by_key.keys
          only_ours = (ours_by_key.keys - theirs_by_key.keys).map { |k| ours_by_key[k] }
          only_theirs = (theirs_by_key.keys - ours_by_key.keys).map { |k| theirs_by_key[k] }
          matched = matched_keys.map { |k| { ours: ours_by_key[k], theirs: theirs_by_key[k] } }

          plan.add_satisfaction_partition(matched: matched, only_ours: only_ours, only_theirs: only_theirs)
          plan.validate_partition_invariant!(:satisfactions,
                                             ours_count: ours_sat.size, theirs_count: theirs_sat.size)
        end

        # Memberships: existing → skip; new + user-exists → add as viewer;
        # unknown → skip with warning. Phase 1 just classifies; the Applier
        # decides what to actually do with the partition.
        def diff_memberships_into(plan)
          theirs = Array(@merge_input.memberships).map { |m| m.is_a?(Hash) ? m : m.to_h }
          ours_emails = @component.project.memberships.includes(:user).filter_map { |m| m.user&.email }.to_set

          matched = []
          only_theirs = []

          theirs.each do |membership|
            email = membership['email']
            if ours_emails.include?(email)
              matched << membership
            else
              only_theirs << membership
            end
          end

          plan.add_membership_partition(matched: matched, only_ours: [], only_theirs: only_theirs)
        end

        # Surface one-sided nested rows (Check/DisaRuleDescription on ours
        # XOR theirs) as resolution_log entries instead of silently dropping
        # them. Phase 1 doesn't insert/delete nested rows;
        # operators see the diagnostic but the merge continues.
        def record_nested_one_sided(plan, rule_id, one_sided_records)
          return if one_sided_records.blank?

          one_sided_records.each do |entry|
            plan.add_resolution_log_entry(
              entry: {
                'type' => 'nested_one_sided',
                'rule_id' => rule_id.to_s,
                'assoc' => entry[:assoc].to_s,
                'side' => entry[:side].to_s,
                'identity' => entry[:identity].to_json,
                'note' => 'nested row present on one side only — not diffed in Phase 1'
              }
            )
          end
        end

        def review_to_hash(review, rule_id)
          {
            'external_id' => review.id,
            'rule_id' => rule_id,
            'comment' => review.comment,
            'created_at' => review.created_at&.iso8601(6),
            'responding_to_external_id' => review.responding_to_review_id
          }
        end

        def sat_key(sat)
          "#{sat['rule_id']}::#{sat['satisfied_by_rule_id']}"
        end
      end
    end
  end
end
