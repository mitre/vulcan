# frozen_string_literal: true

module Import
  module JsonArchive
    module Merge
      # Renders a MergePlan as a human-readable text report for the rake
      # CLI (sync:diff / sync:preview). Extracted to a service class per
      # expert review F19 so it's unit-testable instead of buried in the
      # rake file.
      #
      # No business logic — pure presentation. The plan is the source of
      # truth; formatter just decides how to print it.
      class MergePlanFormatter
        def initialize(plan)
          @plan = plan
        end

        def render
          lines = []
          lines.concat(render_header)
          lines.concat(render_summary)
          lines.concat(render_auto_merged)
          lines.concat(render_conflicts)
          lines.join("\n")
        end

        # Exit code derived from plan content:
        # - 0 if no conflicts (clean — Applier can run auto-resolutions)
        # - 1 if any conflicts present (human must reconcile)
        # Returning 2 for runtime errors is the rake task's job, not ours.
        def exit_code
          @plan.conflicts.empty? ? 0 : 1
        end

        private

        def render_header
          [
            '=== Merge Plan ===',
            "Component:        #{@plan.component_id}",
            "Manifest version: #{@plan.manifest['backup_format_version']}",
            ''
          ]
        end

        def render_summary
          summary = @plan.summary
          lines = ['--- Summary ---']
          MergePlan::ENTITY_KEYS.each do |entity|
            counts = summary[entity]
            lines << format(
              '%-14<entity>s matched=%<m>d  only_ours=%<o>d  only_theirs=%<t>d',
              entity: "#{entity}:", m: counts['matched'], o: counts['only_ours'], t: counts['only_theirs']
            )
          end
          lines << ''
          lines
        end

        def render_auto_merged
          changes = @plan.auto_merged
          return ['--- Auto-merged: (none) ---', ''] if changes.empty?

          lines = ["--- Auto-merged: #{changes.size} field change(s) ---"]
          changes.each { |c| lines << format_change(c) }
          lines << ''
          lines
        end

        def render_conflicts
          changes = @plan.conflicts
          return ['--- Conflicts: (none) ---', ''] if changes.empty?

          lines = ["--- Conflicts: #{changes.size} field(s) — human must reconcile ---"]
          changes.each { |c| lines << format_change(c) }
          lines << ''
          lines
        end

        def format_change(change)
          locked = change.locked ? ' [LOCKED]' : ''
          "  #{change.field}#{locked} (#{change.resolution}): #{truncate(change.from)} → #{truncate(change.to)}"
        end

        def truncate(val)
          str = val.to_s
          str.length > 80 ? "#{str[0, 77]}..." : str
        end
      end
    end
  end
end
