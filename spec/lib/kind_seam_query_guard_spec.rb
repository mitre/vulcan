# frozen_string_literal: true

require 'rails_helper'

# ===========================================================================
# REQUIREMENT: the centralization invariant for requirement-scoped
# triage/comment/disposition queries. Rule is the STIG STI subclass, so
# `Rule.where(component_id:)` or traversing `component.rules` structurally
# excludes authored SrgRules — every such query must route through the kind
# seam (BaseRule.live_for_components / Component#requirements). This guard
# pins the files that have already been migrated; a reintroduction fails
# here with the file and line, not months later as silently missing SRG
# comments in an export.
# ===========================================================================
RSpec.describe 'Kind-seam query invariant' do
  guarded_files = %w[
    app/lib/disposition_matrix_export.rb
    app/services/comment_query_service.rb
    app/models/review.rb
    app/models/reaction.rb
  ]

  # The STI-subclass query shapes that structurally drop SrgRules. Only live
  # code is matched — comment prose legitimately names the anti-pattern when
  # explaining the seam (comment_query_service.rb does exactly that), and a
  # commented-out violation still fails here the moment it is reactivated.
  forbidden_patterns = {
    'Rule.where(component_id:)' => /\bRule\s*\.\s*where\s*\(\s*component_id/,
    'component.rules traversal' => /\bcomponent\s*\.\s*rules\b/
  }

  guarded_files.each do |relative_path|
    describe relative_path do
      let(:lines) { Rails.root.join(relative_path).read.lines }

      forbidden_patterns.each do |label, pattern|
        it "does not use #{label}" do
          offenses = lines.each_with_index.filter_map do |line, index|
            code = line.sub(/#.*/, '')
            "#{relative_path}:#{index + 1}: #{line.strip}" if code.match?(pattern)
          end

          expect(offenses).to be_empty, <<~MSG
            Requirement-scoped queries must go through the kind seam
            (BaseRule.live_for_components / Component#requirements) — Rule is
            the STIG STI subclass and structurally excludes authored SrgRules.
            Offending lines:
            #{offenses.join("\n")}
          MSG
        end
      end
    end
  end

  # =========================================================================
  # REQUIREMENT: the belongs_to :rule read family. Review#rule is the
  # Rule-STI-scoped association — nil for authored-SrgRule commentables and
  # for component-scoped comments — so a dotted `.rule` read on a Review
  # holder assumes Rule kind and ships a 500 for the other kinds. Three live
  # crashes shipped through this family (admin_destroy, move_to_rule, merge
  # labels), and receiver-name greps missed the sites twice; this scan
  # therefore matches EVERY dotted `.rule` read in production code, in every
  # form (direct call, safe navigation, fallback, guard), on every receiver
  # name, and requires each hit to carry a reviewed justification below.
  # Scope note: bare in-object `rule` reads (no receiver dot) are not
  # scannable without drowning in local-variable noise — those live inside
  # Review's own kind-aware accessors, which is where they belong.
  # =========================================================================
  describe 'belongs_to :rule read family (all forms, deny by default)' do
    # Every known dotted `.rule` read, each verified kind-safe. A new hit
    # anywhere else FAILS this scan: rewrite it through the kind-aware
    # accessors (Review#requirement / Review#component), or justify it here
    # after reading the site.
    let(:justified_reads) do
      {
        # Fallback shape — reads commentable when the Rule association is nil.
        'app/blueprints/comment_row_blueprint.rb' => [/review\.rule \|\| review\.commentable/],
        # Component-scoped rows skipped first, then the same fallback shape,
        # then a respond_to? guard before .component.
        'app/controllers/users_controller.rb' => [/r\.rule \|\| r\.commentable/],
        # Receiver is AdditionalAnswer inside the amoeba copy remap — answers
        # exist only on Rules (SrgRules structurally carry none), so the
        # Rule-typed association is the design, not a kind assumption.
        'app/models/component.rb' => [/answer\.rule/, /benchmark\.rule/],
        # redirect_to_parent_if_satisfied_by: guarded `return unless rule`
        # above, and satisfies exists only on Rules — parent is always a Rule.
        'app/models/review.rb' => [/self\.rule = parent/],
        # XCCDF parser mapping objects (happenstance-named .rule accessor on
        # parsed benchmark structures) — not ActiveRecord associations.
        'app/models/security_requirements_guide.rb' => [/parsed_benchmark\.rule/],
        'app/models/stig_rule.rb' => [/group_mapping\.rule/],
        'lib/tasks/stig_and_srg_puller.rake' => [/parsed_benchmark\.rule/],
        # Presence-guarded with an explicit commentable fallback branch.
        'lib/seed_helpers.rb' => [/parent\.rule/]
      }
    end

    let(:production_globs) { %w[app/**/*.rb lib/**/*.rb lib/**/*.rake db/**/*.rb config/**/*.rb] }

    it 'has no unjustified Rule-STI rule reads in production code' do
      offenses = production_globs
                 .flat_map { |glob| Rails.root.glob(glob) }
                 .uniq.sort.flat_map do |path|
        relative = Pathname(path).relative_path_from(Rails.root).to_s
        File.read(path).lines.each_with_index.filter_map do |line, index|
          code = line.sub(/#.*/, '')
          next unless code.match?(/\.rule\b/)
          # Constant receivers (PublishedIdentifiers.rule, ...) are module or
          # class calls — never an instance association read, so never this
          # family. Instance receivers are NEVER filtered by name: that
          # receiver-name blindness is exactly how the family shipped 500s.
          next if code.match?(/\b[A-Z]\w*\.rule\b/) && !code.match?(/\b[a-z_][a-z_0-9]*\.rule\b/)
          next if (justified_reads[relative] || []).any? { |pattern| code.match?(pattern) }

          "#{relative}:#{index + 1}: #{line.strip}"
        end
      end

      expect(offenses).to be_empty, <<~MSG
        Dotted `.rule` reads assume Rule kind — the association is nil for
        authored-SrgRule commentables and component-scoped comments (three
        live 500s shipped this way). Rewrite through Review#requirement /
        Review#component, or add a justified_reads entry AFTER reading the
        site and proving it kind-safe.
        Offending lines:
        #{offenses.join("\n")}
      MSG
    end
  end
end
