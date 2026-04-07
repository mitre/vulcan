# frozen_string_literal: true

# Serializes DISA rule description fields for rule detail and editor views.
class DisaRuleDescriptionBlueprint < Blueprinter::Base
  identifier :id

  fields :vuln_discussion, :false_positives, :false_negatives,
         :documentable, :mitigations, :severity_override_guidance,
         :potential_impacts, :third_party_tools, :mitigation_control,
         :responsibility, :ia_controls, :mitigations_available,
         :poam_available, :poam

  field :_destroy do |_drd, _options|
    false
  end
end
