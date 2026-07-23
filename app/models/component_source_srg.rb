# frozen_string_literal: true

# Join row declaring a source SRG (a parent) of a component. A component
# has 1..N parents; `Component#based_on` designates the primary and must
# always be a member of this set (Component reconciles that on save).
class ComponentSourceSrg < ApplicationRecord
  belongs_to :component, inverse_of: :component_source_srgs
  belongs_to :security_requirements_guide

  validates :security_requirements_guide_id, uniqueness: { scope: :component_id }

  before_destroy :prevent_orphaning_referenced_srg

  private

  # Version-tolerant parent invariant, enforced at its only mutation seam:
  # a parent SRG may leave the set only when another release of the same
  # SRG remains (a version swap) or no live requirement still sources that
  # SRG. Checked against the component's IN-MEMORY association so a
  # same-SRG replacement built in the same save (autosave destroys
  # before it inserts) is recognized.
  def prevent_orphaning_referenced_srg
    return if destroyed_by_association # component teardown cascades freely

    srg_key = security_requirements_guide.srg_id
    siblings = component.component_source_srgs.reject { |row| row.id == id || row.marked_for_destruction? }
    return if siblings.any? { |row| row.security_requirements_guide&.srg_id == srg_key }
    return unless component.requirement_source_srg_referenced?(srg_key)

    errors.add(:base, "cannot remove parent SRG #{srg_key}: still referenced by live requirements")
    throw :abort
  end
end
