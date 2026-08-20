# frozen_string_literal: true

##
# Status-bucket shapes for requirement counts: the five STIG buckets and
# the three SRG buckets. The two shapes are disjoint and never collapse
# into a shared flat list — each authoring profile owns its vocabulary.
module RequirementBuckets
  extend ActiveSupport::Concern

  class_methods do
    # Maps a raw { status string => count } hash into the canonical
    # five-bucket STIG shape. Shared by Component#status_counts and the
    # project-level dashboard aggregation (which GROUPs by component +
    # status in one query).
    def status_buckets(counts)
      {
        not_yet_determined: counts[RuleConstants::STATUS_NYD] || 0,
        applicable_configurable: counts[RuleConstants::STATUS_APPLICABLE_CONFIGURABLE] || 0,
        applicable_inherently_meets: counts[RuleConstants::STATUS_APPLICABLE_IM] || 0,
        applicable_does_not_meet: counts[RuleConstants::STATUS_APPLICABLE_DNM] || 0,
        not_applicable: counts[RuleConstants::STATUS_NOT_APPLICABLE] || 0
      }
    end

    # SRG-kind bucket shape: the three-value profile vocabulary. Keyed
    # from the registry so a vocabulary change cannot drift from the
    # buckets; bare 'Applicable' never joins a shared flat status list.
    def srg_status_buckets(counts)
      nyd, applicable, not_applicable = AuthoringProfile::SRG_STATUSES
      {
        not_yet_determined: counts[nyd] || 0,
        applicable: counts[applicable] || 0,
        not_applicable: counts[not_applicable] || 0
      }
    end
  end
end
