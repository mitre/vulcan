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

        # Memberships imported from theirs always land at the viewer tier
        # regardless of what role the archive carries. NEVER auto-escalates
        # — even if theirs says the user is an admin, an existing admin on
        # the receiving instance must explicitly escalate.
        MEMBERSHIP_IMPORT_ROLE = 'viewer'

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
          @result.attach_plan(@merge_plan)
          @quarantine_buffer = []

          begin
            @sync_event = create_sync_event
            validate_apply_preconditions!
            # Wrap the entire apply in a VulcanAudit correlation scope so
            # every audit row produced by an inner save shares one
            # request_uuid (the sync_id). The merge tag also lands in
            # audit_comment on each save via #audit_comment_for_merge.
            VulcanAudit.with_correlation_scope(uuid: @sync_event.sync_id) do
              with_serializable_transaction do
                acquire_component_lock!
                reload_and_revalidate!
                take_pre_merge_snapshot!
                apply_all
              end
            end
            update_component_sync_metadata
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

          drain_quarantine_buffer!
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
          apply_new_satisfactions
          apply_new_memberships
        end

        # Eager-loaded rules indexed by rule_id, memoized for one apply pass.
        # Shared by apply_rule_field_changes + record_skipped_conflicts so the
        # eager-load (nested associations for v2-480.23 routing) happens once.
        def ours_rules_by_id
          @ours_rules_by_id ||= ours_rules_eager_loaded.index_by(&:rule_id)
        end

        def ours_rules_eager_loaded
          return @component.rules unless @component.is_a?(Component)

          @ours_rules_eager_loaded ||= @component.rules.includes(
            Export::Modes::Backup.new.eager_load_associations
          )
        end

        # Archive rule_id -> live BaseRule.id. Memoized so import_new_reviews
        # and apply_new_satisfactions share a single pluck.
        def rule_id_map
          @rule_id_map ||= @component.rules.pluck(:rule_id, :id).to_h
        end

        # Iterate the plan's auto-resolved FieldChange records, write them
        # to the matching rule via assign + save (hash comparison only —
        # we already vetted the values in RuleFieldDiffer / Analyzer with
        # F14-safe semantics), then capture each effective change as a
        # MergeOperation row.
        def apply_rule_field_changes
          @merge_plan.auto_merged.group_by { |c| rule_id_for(c) }.each do |rule_id, rule_changes|
            rule = ours_rules_by_id[rule_id]
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

            apply_one_rule_change(rule, change, winning_value)
          end
        end

        # Each field write is wrapped in a savepoint so a validation failure
        # on one change quarantines that record and lets the rest of the
        # merge proceed instead of aborting the entire serializable txn.
        def apply_one_rule_change(rule, change, winning_value)
          old_value = rule.public_send(change.field)
          ActiveRecord::Base.transaction(requires_new: true) do
            rule.assign_attributes(change.field => winning_value)
            rule.audit_comment = audit_comment_for_merge
            rule.save!
            log_field_change(rule, change, old_value, winning_value)
          end
        rescue ActiveRecord::RecordInvalid => e
          enqueue_quarantine(
            entity_type: 'rule', entity_key: "#{rule.rule_id}::#{change.field}",
            reason: 'rule validation failed during apply',
            original: { 'rule_id' => rule.rule_id, 'field' => change.field, 'new_value' => winning_value.to_s },
            errors: e
          )
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
          @merge_plan.conflicts.group_by { |c| rule_id_for(c) }.each do |rule_id, changes|
            rule = ours_rules_by_id[rule_id]
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

          builder_result = Import::Result.new

          builder = ReviewBuilder.new(
            new_reviews, rule_id_map, builder_result,
            component: @component, manifest: @merge_plan.manifest
          )
          builder.build_all

          log_review_inserts(builder.external_to_new_id, new_reviews)
          builder_result.warnings.each { |w| @result.add_warning(w) }
        end

        # Walk ReviewBuilder.external_to_new_id and emit one MergeOperation
        # row per actually-inserted Review, with entity_id = new Review.id
        # and entity_key = external_id. Filters out rows ReviewBuilder
        # dropped post-insert via drop_invalid_reviews so audit row count
        # matches DB row count one-for-one.
        def log_review_inserts(external_to_new_id, new_reviews)
          return if external_to_new_id.empty?

          surviving_ids = Review.where(id: external_to_new_id.values).pluck(:id).to_set
          review_index = new_reviews.index_by { |r| r['external_id'] }

          external_to_new_id.each do |external_id, new_id|
            next unless surviving_ids.include?(new_id)

            review_hash = review_index[external_id]
            next if review_hash.nil?

            log_review_insert(new_id, review_hash)
          end
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

          ActiveRecord::Base.transaction(requires_new: true) do
            review.assign_attributes(field => new_value)
            # Defensive dual-write — should be a no-op since rule_id isn't
            # changing here, but the design doc flags it as MUST FIX.
            review.commentable_type ||= 'BaseRule'
            review.commentable_id ||= review.rule_id
            review.audit_comment = audit_comment_for_merge if review.respond_to?(:audit_comment=)
            review.save!
            log_review_update(review, field, current, new_value, verb)
          end
        rescue ActiveRecord::RecordInvalid => e
          enqueue_quarantine(
            entity_type: 'review', entity_key: review.id.to_s,
            reason: 'review validation failed during update',
            original: ours_hash, errors: e
          )
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

        # Insert any only_theirs satisfactions, resolving the archive
        # rule_id strings to live DB ids. Idempotent: re-running the
        # applier against the same plan does NOT duplicate rows because
        # we use upsert_all + on_duplicate: :skip against the natural
        # uniqueness constraint on (rule_id, satisfied_by_rule_id).
        # Missing rule_id targets get a structured warning rather than
        # erroring the whole apply.
        def apply_new_satisfactions
          new_sats = @merge_plan.only_theirs_satisfactions
          return if new_sats.empty?

          new_sats.each { |sat| insert_one_satisfaction(sat, rule_id_map) }
        end

        def insert_one_satisfaction(sat, rule_id_map)
          rule_db_id = rule_id_map[sat['rule_id']]
          satisfier_db_id = rule_id_map[sat['satisfied_by_rule_id']]

          if rule_db_id.nil? || satisfier_db_id.nil?
            missing = rule_db_id.nil? ? sat['rule_id'] : sat['satisfied_by_rule_id']
            @result.add_warning(
              "Satisfaction: rule_id '#{missing}' not present on receiving component — skipped"
            )
            return
          end

          # rubocop:disable Rails/SkipsModelValidations -- RuleSatisfaction
          # is an empty join-table stub (no validations, no callbacks);
          # upsert_all + on_duplicate: :skip is the correct idempotent
          # write per the design doc and v2-480.13 FK convention.
          result = RuleSatisfaction.upsert_all(
            [{ rule_id: rule_db_id, satisfied_by_rule_id: satisfier_db_id }],
            unique_by: %i[rule_id satisfied_by_rule_id],
            on_duplicate: :skip,
            returning: false
          )
          # rubocop:enable Rails/SkipsModelValidations

          # upsert_all returns an Array<Hash> of inserted rows (returning: false skips that);
          # we use record_rowcount via raw connection diagnostic. Simpler: query existence
          # afterwards — present means we either just inserted OR it already existed.
          # Either way, log an operation for audit (operation=insert; idempotent retries
          # produce an extra log row but the underlying state is unchanged).
          _ = result # suppress UnusedMethodArgument
          log_satisfaction_insert(sat, rule_db_id, satisfier_db_id)
        end

        def apply_new_memberships
          new_memberships = @merge_plan.only_theirs_memberships
          return if new_memberships.empty?

          new_memberships.each { |membership| insert_one_membership(membership) }
        end

        def insert_one_membership(membership_hash)
          email = membership_hash['email']
          user = User.find_by(email: email)
          if user.nil?
            @result.add_warning(
              "Membership: user '#{email}' not present on receiving instance — skipped (archive did not auto-create the account)"
            )
            return
          end

          # Skip if already a member at any role (matched bucket should
          # cover this, but defensive against partition drift).
          existing = Membership.find_by(user: user, membership: @component.project)
          return if existing

          ActiveRecord::Base.transaction(requires_new: true) do
            Membership.create!(user: user, membership: @component.project, role: MEMBERSHIP_IMPORT_ROLE)
            log_membership_insert(membership_hash, user)
          end
        rescue ActiveRecord::RecordInvalid => e
          enqueue_quarantine(
            entity_type: 'membership', entity_key: membership_hash['email'].to_s,
            reason: 'membership validation failed', original: membership_hash, errors: e
          )
        end

        # When a per-record save fails validation mid-apply, the offending
        # record + diagnostics are BUFFERED for post-txn persistence so the
        # outer txn rolling back (SerializationFailure, StandardError, etc.)
        # does NOT also discard the diagnostic trail. drain_quarantine_buffer!
        # writes the rows AFTER the outer rescue, in autocommit / RSpec-txn
        # mode — preserving the "retry via sync:retry_quarantined" contract.
        def enqueue_quarantine(entity_type:, entity_key:, reason:, original:, errors:)
          @quarantine_buffer << {
            entity_type: entity_type, entity_key: entity_key.to_s, reason: reason,
            original: original, errors: errors
          }
        end

        # Persist buffered quarantine intents after the outer txn closes
        # (committed or rolled back). Each create! runs in whatever
        # transaction scope the caller is in — production: autocommit (the
        # outer with_serializable_transaction has closed); tests: RSpec's
        # wrapping fixture txn (still visible to the test).
        def drain_quarantine_buffer!
          return if @quarantine_buffer.blank?
          return if @sync_event.nil?

          @quarantine_buffer.each do |q|
            begin
              MergeQuarantineRecord.create!(
                component_sync_event: @sync_event,
                entity_type: q[:entity_type],
                entity_key: q[:entity_key],
                quarantine_reason: q[:reason],
                original_archive_data: q[:original],
                validation_errors: { 'message' => q[:errors].message, 'class' => q[:errors].class.name }
              )
            rescue StandardError => e
              @result.add_warning(
                "Failed to persist quarantine for #{q[:entity_type]} '#{q[:entity_key]}': #{e.message}"
              )
              next
            end
            @result.add_warning(
              "#{q[:entity_type]}: '#{q[:entity_key]}' quarantined — #{q[:errors].message} " \
              '(see merge_quarantine for diagnostics)'
            )
          end
        end

        def log_membership_insert(membership_hash, user)
          MergeOperation.create!(
            component_sync_event: @sync_event,
            entity_type: 'membership',
            entity_id: user.id,
            entity_key: membership_hash['email'].to_s,
            operation: 'insert',
            field_name: 'role',
            old_value: nil,
            new_value: MEMBERSHIP_IMPORT_ROLE,
            source: 'theirs'
          )
        end

        def log_satisfaction_insert(sat, rule_db_id, satisfier_db_id)
          MergeOperation.create!(
            component_sync_event: @sync_event,
            entity_type: 'satisfaction',
            entity_id: rule_db_id,
            entity_key: "#{sat['rule_id']}::#{sat['satisfied_by_rule_id']}",
            operation: 'insert',
            field_name: nil,
            old_value: nil,
            new_value: satisfier_db_id.to_s,
            source: 'theirs'
          )
        end

        def log_review_insert(new_id, review_hash)
          MergeOperation.create!(
            component_sync_event: @sync_event,
            entity_type: 'review',
            entity_id: new_id,
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
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
          raise PreconditionError,
                'another sync is already in progress on this component (a pending ' \
                'ComponentSyncEvent exists — wait for it to complete or fail)'
        end

        # Session-scoped advisory lock keyed on component.id. Two operators
        # racing sync:apply serialize here; auto-released at outer txn
        # commit/rollback. Different components merge concurrently.
        def acquire_component_lock!
          ActiveRecord::Base.connection.execute(
            "SELECT pg_advisory_xact_lock(#{@component.id.to_i})"
          )
        end

        # Inside the locked txn, re-read the component under SELECT FOR
        # UPDATE and re-validate preconditions against the just-read row.
        # Catches: (a) component destroyed between pre-check and apply,
        # (b) comment_phase reopened mid-flight by another operator.
        def reload_and_revalidate!
          @component.lock!
          validate_apply_preconditions!
        rescue ActiveRecord::RecordNotFound
          raise PreconditionError, 'component was destroyed during merge'
        end

        # The apply path requires concurrent-edit protection — the
        # receiving component must be in 'closed' comment_phase so no one
        # is mid-write while we apply theirs. Analyzer (read-only) does
        # not require this. Called once before opening the txn (fast-fail)
        # and again after acquiring the advisory + row lock inside the txn.
        # Raises PreconditionError on failure so the same exception class
        # is used uniformly across the analyze + apply boundary.
        def validate_apply_preconditions!
          return if @component.comment_phase == Analyzer::COMMENT_PHASE_REQUIRED

          raise PreconditionError,
                "component.comment_phase must be '#{Analyzer::COMMENT_PHASE_REQUIRED}' to apply " \
                "(got '#{@component.comment_phase}')"
        end

        # Captures the current state of the receiving component as a
        # zip + checksum so disaster-recovery (v2-480.10) can restore it
        # if a merge is reverted. Snapshot path recorded on the sync event.
        # Runs inside the locked apply transaction so the captured state
        # reflects the actual apply pre-state (post-lock, pre-write).
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

        # Stamp the receiving component with the sync event details so
        # the UI / audit history can show "last synced from <source> at
        # <time>" for operators. Only runs on a successful apply — the
        # ensure block in #call does NOT update these on failure so
        # operators can see the still-pending sync state and retry.
        def update_component_sync_metadata
          @component.update_columns( # rubocop:disable Rails/SkipsModelValidations -- sync metadata is internal bookkeeping, no validations apply
            last_sync_id: @sync_event.sync_id,
            last_sync_at: Time.current,
            last_sync_source: @source
          )
        end

        # Tag every save with the merge sync_id so audit history can group
        # all rows from one merge. Paired with the correlation-scope
        # request_uuid; comment text is the human-readable lookup.
        def audit_comment_for_merge
          "merge:#{@sync_event.sync_id}"
        end

        def mark_event_status(status)
          return if @sync_event.nil?

          @sync_event.update!(status: status)
        end
      end
    end
  end
end
