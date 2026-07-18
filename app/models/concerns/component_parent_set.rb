# frozen_string_literal: true

# The multi-parent source-SRG set of a component. based_on IS the primary
# parent: assigning it reconciles the join set (inserting the new member
# and superseding any same-family member), membership is validated, and
# parent eligibility comes from the AuthoringProfile registry policy.
module ComponentParentSet
  extend ActiveSupport::Concern

  included do
    # autosave is required: based_on reconciliation supersedes same-family
    # members via mark_for_destruction, which a has_many silently ignores
    # at save unless autosave is declared.
    has_many :component_source_srgs, dependent: :destroy, inverse_of: :component,
                                     autosave: true
    has_many :source_srgs, through: :component_source_srgs,
                           source: :security_requirements_guide

    before_validation :reconcile_based_on_into_source_srgs
    validate :based_on_must_be_declared_parent
    validate :parents_must_satisfy_profile_eligibility
  end

  # Declared parents whose family has a newer release — primary first, so
  # the update affordance targets the primary's upgrade when several are
  # stale. Currency is a property of the WHOLE parent set.
  def stale_parents
    source_srgs.to_a
               .sort_by { |srg| srg.id == security_requirements_guide_id ? 0 : 1 }
               .reject(&:latest?)
  end

  # Current only when every declared parent is its family's latest.
  def parents_current?
    parents = source_srgs.to_a
    parents.present? && parents.all?(&:latest?)
  end

  # Replace the declared member of new_srg's family with new_srg — the
  # revision upgrade path for a non-primary parent. Safe on unsaved
  # amoeba copies: built rows are dropped from the target, persisted rows
  # marked for destruction (autosave destroys them in the save).
  def replace_parent_family(new_srg)
    supersede_family_members(new_srg.srg_id)
    component_source_srgs.build(security_requirements_guide: new_srg)
  end

  # Does any live requirement of this component source the given SRG
  # family (srg_id)? Version-tolerant: a Rule's srg_rule or an authored
  # SrgRule's derived_from may reference ANY catalog version of the
  # family. Used by the join-row destroy guard.
  def requirement_family_referenced?(family)
    BaseRule.live_for_components([id])
            .joins('INNER JOIN base_rules sources ' \
                   'ON sources.id = COALESCE(base_rules.srg_rule_id, base_rules.derived_from_srg_rule_id)')
            .joins('INNER JOIN security_requirements_guides families ' \
                   'ON families.id = sources.security_requirements_guide_id')
            .exists?(families: { srg_id: family })
  end

  private

  # Assigning based_on inserts it into the parent set atomically. A
  # same-family member (same srg_id, e.g. the prior version during a
  # revision) is superseded — replaced, never appended unbounded. A
  # new-family based_on is added alongside the existing declared parents.
  def reconcile_based_on_into_source_srgs
    return if security_requirements_guide_id.blank?

    active = component_source_srgs.reject(&:marked_for_destruction?)
    return if active.any? { |row| row.security_requirements_guide_id == security_requirements_guide_id }

    family = based_on&.srg_id
    supersede_family_members(family) if family
    # Build by id, not by assigning based_on's instance — its trimmed
    # select would poison later attribute reads through the join row.
    component_source_srgs.build(security_requirements_guide_id: security_requirements_guide_id)
  end

  def supersede_family_members(family)
    component_source_srgs.reject(&:marked_for_destruction?).each do |row|
      next unless row.security_requirements_guide&.srg_id == family

      row.persisted? ? row.mark_for_destruction : component_source_srgs.delete(row)
    end
  end

  def based_on_must_be_declared_parent
    return if security_requirements_guide_id.blank?

    active = component_source_srgs.reject(&:marked_for_destruction?)
    return if active.any? { |row| row.security_requirements_guide_id == security_requirements_guide_id }

    errors.add(:security_requirements_guide_id, 'must be a declared source SRG of the component')
  end

  # Parent eligibility is per-profile policy from the registry (the only
  # kind-difference in the multi-parent model). Reads each parent through
  # the join row's association — NOT through based_on, whose trimmed
  # select omits the core column.
  def parents_must_satisfy_profile_eligibility
    # An unknown profile is the inclusion validation's rejection to make —
    # never a registry KeyError from here.
    return unless AuthoringProfile.profile?(document_type)

    profile = AuthoringProfile.for(document_type)
    offending = component_source_srgs.reject(&:marked_for_destruction?)
                                     .filter_map(&:security_requirements_guide)
                                     .reject { |srg| profile.parent_eligible?(srg) }
    return if offending.none?

    errors.add(:base,
               "every parent of a #{document_type} component must be #{profile.parent_eligibility_requirement} " \
               "(ineligible: #{offending.map(&:srg_id).uniq.join(', ')})")
  end
end
