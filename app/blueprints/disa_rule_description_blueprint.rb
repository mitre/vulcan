# frozen_string_literal: true

class DisaRuleDescriptionBlueprint < Blueprinter::Base
  identifier :id

  fields :vuln_discussion,
         :false_negatives,
         :false_positives,
         :documentable,
         :mitigations,
         :mitigations_available,
         :poam,
         :poam_available,
         :severity_override_guidance,
         :potential_impacts,
         :third_party_tools,
         :mitigation_control,
         :responsibility,
         :ia_controls
end
