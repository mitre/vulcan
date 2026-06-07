# frozen_string_literal: true

module Import
  module JsonArchive
    module Merge
      # Thin orchestrator behind the sync:diff and sync:preview rake
      # tasks. Extracted from the rake file so the exit-code contract
      # (F15: 0=clean, 1=conflicts, 2=error) and IO behavior are
      # unit-testable without forking a process or rescuing SystemExit.
      class SyncRakeRunner
        def initialize(stdout, stderr)
          @stdout = stdout
          @stderr = stderr
        end

        # Two-archive diff: ours_path and theirs_path are both zip paths.
        # Wraps the ours archive in a Component-quacking adapter so the
        # Analyzer pipeline works without a DB.
        def diff(ours_path:, theirs_path:)
          ours_input = MergeInput.from_zip_path(ours_path)
          theirs_input = MergeInput.from_zip_path(theirs_path)
          virtual = VirtualComponent.new(ours_input)

          run(theirs_input, virtual)
        rescue ArgumentError, Errno::ENOENT, Zip::Error => e
          @stderr.puts("sync:diff: #{e.message}")
          2
        end

        # Live-component preview: theirs_path is a zip, ours is the live
        # Component identified by component_id.
        def preview(component_id:, theirs_path:)
          component = Component.find(component_id)
          theirs_input = MergeInput.from_zip_path(theirs_path)

          run(theirs_input, component)
        rescue ActiveRecord::RecordNotFound, ArgumentError, Errno::ENOENT, Zip::Error => e
          @stderr.puts("sync:preview: #{e.message}")
          2
        end

        private

        def run(theirs_input, component)
          plan = Analyzer.new(
            merge_input: theirs_input, component: component,
            strategy: Strategy.new, manifest: theirs_input.manifest
          ).call

          formatter = MergePlanFormatter.new(plan)
          @stdout.puts(formatter.render)
          formatter.exit_code
        rescue PreconditionError => e
          @stderr.puts("Precondition failed: #{e.message}")
          2
        end

        # Adapter so the two-archive diff path can hand the Analyzer
        # something that responds to the same surface as a live Component.
        # Phase 1 fidelity — Phase 2 orchestrator passes real AR records
        # directly and this layer goes away.
        class VirtualComponent
          attr_reader :id, :comment_phase

          def initialize(merge_input)
            @merge_input = merge_input
            @id = 0
            @comment_phase = Analyzer::COMMENT_PHASE_REQUIRED
          end

          def rules
            @rules ||= build_rules
          end

          def project
            @project ||= VirtualProject.new(@merge_input.memberships)
          end

          private

          def build_rules
            reviews_by_rule = @merge_input.reviews.group_by { |r| r['rule_id'] }
            satisfies_by_satisfier = @merge_input.satisfactions.group_by { |s| s['satisfied_by_rule_id'] }

            @merge_input.rules.map do |rule_hash|
              rule_id = rule_hash['rule_id']
              VirtualRule.new(
                rule_hash: rule_hash,
                reviews: (reviews_by_rule[rule_id] || []).map { |r| VirtualReview.new(r) },
                satisfies: (satisfies_by_satisfier[rule_id] || []).map { |s| VirtualSatisfied.new(s['rule_id']) }
              )
            end
          end
        end

        # Rule-shaped adapter: exposes rule_id, attributes, reviews,
        # satisfies, locked_fields, and nested associations (checks,
        # disa_rule_descriptions) for the Analyzer + NestedAssociationDiffer.
        class VirtualRule
          attr_reader :rule_id, :reviews, :satisfies, :locked_fields, :attributes

          def initialize(rule_hash:, reviews:, satisfies:)
            @rule_id = rule_hash['rule_id']
            @attributes = rule_hash
            @reviews = reviews
            @satisfies = satisfies
            # Preserve the real JSONB shape — {"Section" => true} — so
            # RuleFieldDiffer's section-keyed lock check works.
            @locked_fields = rule_hash['locked_fields'] || {}
          end

          # Nested-association accessors. Lazy-build VirtualNestedRecord
          # wrappers for each row in the archive's nested arrays.
          Rule::NESTED_MERGEABLE_ASSOCIATIONS.each do |assoc_name, config|
            define_method(assoc_name) do
              @nested_cache ||= {}
              @nested_cache[assoc_name] ||= Array(@attributes[config[:backup_key]])
                                            .map { |h| VirtualNestedRecord.new(h) }
            end
          end
        end

        # Hash-backed adapter that quacks like an AR nested record:
        # supports #attributes (raw hash) and dynamic accessors for each
        # column. NestedAssociationDiffer needs both (attributes for
        # field-by-field comparison, accessors for identity_keys).
        class VirtualNestedRecord
          def initialize(hash)
            @attributes = (hash || {}).dup
          end

          attr_reader :attributes

          def method_missing(name, *_args)
            key = name.to_s
            return @attributes[key] if @attributes.key?(key)

            super
          end

          def respond_to_missing?(name, _include_private = false)
            @attributes.key?(name.to_s) || super
          end
        end

        # Review-shaped adapter — exposes the four fields Analyzer's
        # review_to_hash reads (id/comment/responding_to_review_id/created_at).
        class VirtualReview
          attr_reader :id, :comment, :responding_to_review_id

          def initialize(hash)
            @id = hash['external_id']
            @comment = hash['comment']
            @responding_to_review_id = hash['responding_to_external_id']
            @created_at_raw = hash['created_at']
          end

          # Analyzer calls created_at&.iso8601(6); accept both string and Time.
          def created_at
            return nil if @created_at_raw.nil?
            return @created_at_raw if @created_at_raw.respond_to?(:iso8601)

            Time.zone.parse(@created_at_raw.to_s)
          end
        end

        # Satisfaction stub: only exposes rule_id (the satisfied side),
        # which is what Analyzer's diff_satisfactions_into reads.
        class VirtualSatisfied
          attr_reader :rule_id

          def initialize(rule_id)
            @rule_id = rule_id
          end
        end

        # Project-shaped adapter — exposes #memberships returning a scope.
        class VirtualProject
          def initialize(memberships)
            @memberships = Array(memberships)
          end

          def memberships
            VirtualMembershipScope.new(@memberships)
          end
        end

        # Imitates an AR relation: supports #includes (no-op) and chained
        # #filter_map via Enumerable.
        class VirtualMembershipScope
          include Enumerable

          def initialize(memberships)
            @memberships = memberships.map { |m| VirtualMembership.new(m) }
          end

          def each(&)
            @memberships.each(&)
          end

          # Mimic AR's includes — no-op for our purposes, but Analyzer
          # chains .includes(:user) before filter_map.
          def includes(*)
            self
          end
        end

        # One row in VirtualProject#memberships — exposes a #user that
        # responds to #email so Analyzer's membership iteration works.
        class VirtualMembership
          attr_reader :user

          def initialize(hash)
            @user = VirtualUser.new(hash || {})
          end
        end

        # Member-side user adapter — Analyzer reads m.user&.email.
        class VirtualUser
          attr_reader :email

          def initialize(hash)
            @email = hash['email']
          end
        end
      end
    end
  end
end
