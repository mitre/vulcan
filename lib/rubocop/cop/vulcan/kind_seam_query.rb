# frozen_string_literal: true

module RuboCop
  module Cop
    module Vulcan
      # Enforces the kind-seam query invariant in requirement-scoped code.
      #
      # Rule is the STIG STI subclass of BaseRule, so class-level Rule
      # queries (`Rule.where`, `Rule.find_by`, `Rule.pluck`, ...) and
      # `<receiver>.rules` traversal structurally exclude authored
      # SrgRules — an srg-kind component's requirements.
      # A requirement-scoped query written against the Rule branch returns
      # silently-empty (or wrong-family) results for SRG components, which
      # surfaces months later as missing rows in exports, searches, and
      # comment queries rather than as an error.
      #
      # Route through the kind seam instead: Component#requirements,
      # BaseRule.live_for_components, or
      # ComponentBlueprint.requirement_blueprint.
      #
      # Deliberately STIG-only surfaces (the satisfies graph, InSpec,
      # spreadsheet import internals, counter-cache maintenance) are
      # allowlisted PER FILE in .rubocop.yml, each with a one-line
      # justification — never quieted with inline disables.
      #
      # @example Bad
      #   Rule.where(component_id: component.id)
      #   Rule.joins(:reviews).where(component_id: ids)
      #   component.rules.pluck(:rule_id)
      #
      # @example Good
      #   component.requirements.pluck(:rule_id)
      #   BaseRule.live_for_components(component_ids)
      class KindSeamQuery < Base
        MSG = 'Requirement-scoped queries must go through the kind seam ' \
              '(Component#requirements / BaseRule.live_for_components) — Rule is the ' \
              'STIG STI subclass and structurally excludes authored SRG requirements. ' \
              'Deliberately STIG-only surfaces are allowlisted per file in .rubocop.yml.'

        # The only legal class-level calls on Rule: identity lookup by id,
        # deliberate construction (creating a Rule is a kind-chosen act),
        # and transaction (which opens on the connection — the class carries
        # no query semantics). Every other class-level call — where, joins,
        # find_by, pluck, count, exists?, and the rest of the query API —
        # can express a requirement-scoped query that drops authored SRG
        # requirements, so the matcher denies by default rather than
        # enumerating query verbs.
        LEGAL_CLASS_CALLS = %i[find new create create! transaction].freeze

        def_node_matcher :rule_class_call, <<~PATTERN
          (send (const {nil? cbase} :Rule) $_ ...)
        PATTERN

        # <receiver>.rules — the Rule-only association traversal. Explicit
        # receivers only: a bare `rules` call inside Component is the
        # association's own home.
        def_node_matcher :rules_traversal?, <<~PATTERN
          (send !nil? :rules)
        PATTERN

        def on_send(node)
          return add_offense(node) if rules_traversal?(node)

          selector = rule_class_call(node)
          return if selector.nil? || LEGAL_CLASS_CALLS.include?(selector)

          add_offense(node)
        end
      end
    end
  end
end
