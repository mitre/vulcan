# frozen_string_literal: true

require 'securerandom'
require 'digest'

module Import
  module JsonArchive
    module Merge
      # Phase 2 write-side counterpart to Analyzer. Takes a resolved
      # MergePlan and applies it to the database under a serializable
      # transaction with a pre-merge snapshot, capturing every write to
      # merge_operations + a ComponentSyncEvent row for auditability.
      #
      # Phase 1 commit (skeleton): the lifecycle + sync event + transaction
      # wrapper land here. Per-entity apply logic (rules, reviews,
      # satisfactions, memberships) lands in subsequent commits.
      class Applier
        TRANSACTION_ISOLATION = :serializable
        VALID_SOURCES = %w[theirs ours auto_merge].freeze

        # Reviews are mostly immutable, but a few lifecycle fields legit
        # change post-creation (triage state, adjudication, rule-addressed
        # links). The merge engine respects Strategy on these — by
        # default ours wins on triage_status.
        REVIEW_MERGEABLE_FIELDS = %w[
          triage_status triage_set_by_imported_email triage_set_by_imported_name
          adjudicated_at adjudicated_by_imported_email adjudicated_by_imported_name
          addressed_by_rule_id
        ].freeze

        attr_reader :sync_event

        # @param merge_plan [MergePlan] from Analyzer#call
        # @param component [Component] the receiving component (live AR)
        # @param source [String] one of VALID_SOURCES — labels the
        #   ComponentSyncEvent's source field
        # @param archive_bytes [String, nil] raw zip bytes for SHA-256
        #   hashing (commit 2 wires this in for replay protection)
        def initialize(merge_plan:, component:, source:, archive_bytes: nil)
          @merge_plan = merge_plan
          @component = component
          @source = source
          @archive_bytes = archive_bytes
          @result = MergeResult.new
        end

        def call
          @sync_event = create_sync_event
          @result.attach_plan(@merge_plan)

          begin
            validate_apply_preconditions!
            take_pre_merge_snapshot!
            with_serializable_transaction { apply_all }
            mark_event_status('applied')
          rescue PreconditionError => e
            mark_event_status('failed')
            @result.add_structured_error(
              entity_type: :component, entity_key: @component.id.to_s,
              step: :precondition, message: e.message
            )
          rescue ActiveRecord::SerializationFailure
            mark_event_status('failed')
            @result.add_structured_error(
              entity_type: :component, entity_key: @component.id.to_s,
              step: :apply, message: 'component modified during merge (serialization conflict)'
            )
          rescue StandardError => e
            mark_event_status('failed')
            @result.add_structured_error(
              entity_type: :component, entity_key: @component.id.to_s,
              step: :apply, message: "#{e.class.name}: #{e.message}"
            )
          end

          @result
        end

        private

        # Per-entity apply pipeline. Each commit fills in one entity.
        def apply_all
          apply_rule_field_changes
          record_skipped_conflicts
          recalculate_rules_count
          import_new_reviews
          apply_review_field_updates
          Review.where(commentable_id: nil).where.not(rule_id: nil).repair_missing_commentable!
          # Satisfactions, memberships land in c7-c8.
        end

        # Iterate the plan's auto-resolved FieldChange records, write them
        # to the matching rule via assign + save (hash comparison only —
        # we already vetted the values in RuleFieldDiffer / Analyzer with
        # F14-safe semantics), then capture each effective change as a
        # MergeOperation row.
        def apply_rule_field_changes
          rules_by_id = @component.rules.index_by(&:rule_id)

          @merge_plan.auto_merged.group_by { |c| rule_id_for(c) }.each do |rule_id, rule_changes|
            rule = rules_by_id[rule_id]
            next if rule.nil? # only_theirs rules don't exist yet — handled by a later pass

            apply_changes_to_rule(rule, rule_changes)
          end
        end

        # FieldChange records carry no rule_id field, but the MergePlan
        # groups them by rule_id internally. Build a reverse lookup once
        # per call so the partition iteration above is O(N).
        def rule_id_for(change)
          @field_changes_index ||= @merge_plan.instance_variable_get(:@field_changes)
                                              .flat_map { |rid, list| list.map { |c| [c, rid] } }
                                              .to_h
          @field_changes_index[change]
        end

        def apply_changes_to_rule(rule, changes)
          changes.each do |change|
            winning_value = winning_value_for(change)
            next if winning_value == rule.public_send(change.field)

            old_value = rule.public_send(change.field)
            rule.assign_attributes(change.field => winning_value)
            rule.save!
            log_field_change(rule, change, old_value, winning_value)
          end
        end

        # For auto_theirs the incoming value wins; for everything else
        # (auto_ours, auto_merged, and the defensive default if a
        # caller leaks a :conflict through) ours stays.
        def winning_value_for(change)
          change.resolution == :auto_theirs ? change.to : change.from
        end

        def log_field_change(rule, change, old_value, new_value)
          MergeOperation.create!(
            component_sync_event: @sync_event,
            entity_type: 'rule',
            entity_id: rule.id,
            entity_key: rule.rule_id,
            operation: 'update',
            field_name: change.field,
            old_value: old_value.to_s,
            new_value: new_value.to_s,
            source: source_for(change.resolution)
          )
        end

        def source_for(resolution)
          case resolution
          when :auto_ours then 'ours'
          when :auto_theirs then 'theirs'
          when :auto_merged then 'auto_merge'
          else 'conflict_resolved'
          end
        end

        # Conflicts (:conflict, :locked_conflict) are NEVER auto-applied —
        # by contract they require a human decision. We still record each
        # one as a merge_operations row with operation=skip so the audit
        # trail captures "we saw this divergence, didn't act on it" and
        # the UI / undo path can replay decisions if needed.
        def record_skipped_conflicts
          rules_by_id = @component.rules.index_by(&:rule_id)

          @merge_plan.conflicts.group_by { |c| rule_id_for(c) }.each do |rule_id, changes|
            rule = rules_by_id[rule_id]
            next if rule.nil?

            changes.each { |change| log_skipped_conflict(rule, change) }
          end
        end

        def log_skipped_conflict(rule, change)
          MergeOperation.create!(
            component_sync_event: @sync_event,
            entity_type: 'rule',
            entity_id: rule.id,
            entity_key: rule.rule_id,
            operation: 'skip',
            field_name: change.field,
            old_value: change.from.to_s,
            new_value: change.to.to_s,
            source: 'conflict_resolved'
          )
        end

        # Reviews that exist only on theirs side need to be imported into
        # the receiving component. Delegate to the existing ReviewBuilder
        # two-pass — it already handles user-resolution, threaded-reply
        # relinking, and the post-import commentable repair pass.
        # Each successful insert is logged as a merge_operations row for
        # parity with the rule-field-change records.
        def import_new_reviews
          new_reviews = @merge_plan.only_theirs_reviews
          return if new_reviews.empty?

          # ReviewBuilder needs a rule_id (archive string) -> DB id map.
          # The applier already has the live component, so just walk it.
          rule_id_map = @component.rules.pluck(:rule_id, :id).to_h
          builder_result = Import::Result.new

          inserted = ReviewBuilder.new(
            new_reviews, rule_id_map, builder_result,
            component: @component, manifest: @merge_plan.manifest
          ).build_all

          new_reviews.first(inserted).each { |review_hash| log_review_insert(review_hash) }
          builder_result.warnings.each { |w| @result.add_warning(w) }
        end

        # For each {ours:, theirs:} review pair in the matched bucket,
        # walk REVIEW_MERGEABLE_FIELDS and update any divergence per
        # Strategy. Dual-write commentable_type/id on every save to keep
        # the comment-triage read paths consistent. The post-loop
        # repair_missing_commentable! is a defensive net (callbacks
        # should set commentable, but bulk paths historically have not).
        def apply_review_field_updates
          @merge_plan.matched_reviews.each do |pair|
            ours = pair[:ours] || pair['ours']
            theirs = pair[:theirs] || pair['theirs']
            next if ours.nil? || theirs.nil?

            update_one_review(ours, theirs)
          end
        end

        def update_one_review(ours_hash, theirs_hash)
          review_id = ours_hash['external_id']
          return if review_id.nil?

          review = Review.find_by(id: review_id)
          return if review.nil?

          REVIEW_MERGEABLE_FIELDS.each do |field|
            next unless theirs_hash.key?(field)

            verb = @merge_plan.strategy.for_field(:review, field)
            next if verb == :skip

            apply_review_field(review, ours_hash, theirs_hash, field, verb)
          end
        end

        def apply_review_field(review, ours_hash, theirs_hash, field, verb)
          new_value = case verb
                      when :theirs then theirs_hash[field]
                      when :ours then ours_hash[field]
                      else return # :conflict, :newer, etc. — Phase 1 does not auto-merge
                      end

          current = review.public_send(field)
          return if current == new_value

          review.assign_attributes(field => new_value)
          # Defensive dual-write — should be a no-op since rule_id isn't
          # changing here, but the design doc flags it as MUST FIX.
          review.commentable_type ||= 'BaseRule'
          review.commentable_id ||= review.rule_id
          review.save!
          log_review_update(review, field, current, new_value, verb)
        end

        def log_review_update(review, field, old_value, new_value, verb)
          MergeOperation.create!(
            component_sync_event: @sync_event,
            entity_type: 'review',
            entity_id: review.id,
            entity_key: review.id.to_s,
            operation: 'update',
            field_name: field,
            old_value: old_value.to_s,
            new_value: new_value.to_s,
            source: source_for_verb(verb)
          )
        end

        def source_for_verb(verb)
          case verb
          when :ours then 'ours'
          when :theirs then 'theirs'
          else 'auto_merge'
          end
        end

        def log_review_insert(review_hash)
          MergeOperation.create!(
            component_sync_event: @sync_event,
            entity_type: 'review',
            entity_id: 0, # filled by Phase 2c when we round-trip back via the new_id map
            entity_key: review_hash['external_id'].to_s,
            operation: 'insert',
            field_name: nil,
            old_value: nil,
            new_value: review_hash['comment'].to_s,
            source: 'theirs'
          )
        end

        # Counter cache safety net: the component's rules_count column can
        # drift if any apply path bypasses callbacks. Recalc from the
        # source of truth (rules with deleted_at IS NULL) after rule writes.
        def recalculate_rules_count
          fresh_count = @component.rules.where(deleted_at: nil).count
          @component.update_columns(rules_count: fresh_count) # rubocop:disable Rails/SkipsModelValidations -- counter cache repair only
        end

        def create_sync_event
          ComponentSyncEvent.create!(
            component: @component,
            sync_id: SecureRandom.uuid,
            source: @source,
            direction: 'inbound',
            status: 'pending',
            resolution_log_json: @merge_plan.resolution_log,
            archive_hash: @archive_bytes && Digest::SHA256.hexdigest(@archive_bytes)
          )
        end

        # The apply path requires concurrent-edit protection — the
        # receiving component must be in 'closed' comment_phase so no one
        # is mid-write while we apply theirs. Analyzer (read-only) does
        # not require this. Raises PreconditionError on failure
        # so the same exception class is used uniformly across the
        # analyze + apply boundary.
        def validate_apply_preconditions!
          return if @component.comment_phase == Analyzer::COMMENT_PHASE_REQUIRED

          raise PreconditionError,
                "component.comment_phase must be '#{Analyzer::COMMENT_PHASE_REQUIRED}' to apply " \
                "(got '#{@component.comment_phase}')"
        end

        # Captures the current state of the receiving component as a
        # zip + checksum so disaster-recovery (v2-480.10) can restore it
        # if a merge is reverted. Snapshot path recorded on the sync event.
        def take_pre_merge_snapshot!
          path = SnapshotManager.create_snapshot(@component)
          @sync_event.update!(snapshot_path: path)
        end

        # When the applier is invoked outside an existing transaction (the
        # production controller / rake path), request serializable
        # isolation explicitly so concurrent writers are caught via
        # SerializationFailure. When already inside a transaction (test
        # fixtures, or a caller that already opened one), join it — PG
        # only allows isolation to be set on the outermost transaction.
        def with_serializable_transaction(&)
          if ActiveRecord::Base.connection.transaction_open?
            ActiveRecord::Base.transaction(&)
          else
            ActiveRecord::Base.transaction(isolation: TRANSACTION_ISOLATION, &)
          end
        end

        def mark_event_status(status)
          return if @sync_event.nil?

          @sync_event.update!(status: status)
        end
      end
    end
  end
end
