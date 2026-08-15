import { unref } from "vue";
import { ruleTerm } from "../constants/terminology";

export const HUMANIZED_TYPES = {
  AdditionalAnswer: "Additional Answer",
  AdditionalQuestion: "Additional Question",
  BaseRule: "Rule",
  RuleDescription: "Rule Description",
  DisaRuleDescription: "Rule Description",
  created_at: "Created At",
  updated_at: "Updated At",
  project_id: "Project ID",
  status_justification: "Status Justification",
  artifact_description: "Artifact Description",
  vendor_comments: "Vendor Comments",
  rule_id: "Rule ID",
  rule_severity: "Rule Severity",
  rule_weight: "Rule Weight",
  ident_system: "Identity System",
  fixtext: "Fix Text",
  fixtext_fixref: "Fix Text Reference",
  fix_id: "Fix ID",
  vuln_discussion: "Vulnerability Discussion",
  false_positives: "False Positives",
  false_negatives: "False Negatives",
  severity_override_guidance: "Severity Override Guidance",
  potential_impacts: "Potential Impacts",
  third_party_tools: "Third party Tools",
  mitigation_control: "Mitigation Control",
  ia_controls: "IA Controls",
  content_ref_name: "Content Reference Name",
  content_ref_href: "Content Reference Link",
  system: "System",
  content: "Check",
  documentable: "Documentable",
  mitigations: "Mitigations",
  locked: "Locked",
  locked_at: "Account Locked",
  status: "Status",
  title: "Title",
  ident: "Ident",
};

// Entries whose label carries the entity noun — rebuilt per component kind
// so SRG changelogs speak in Requirement terms.
const kindKeyedOverrides = (noun) => ({
  BaseRule: noun,
  RuleDescription: `${noun} Description`,
  DisaRuleDescription: `${noun} Description`,
  rule_id: `${noun} ID`,
  rule_severity: `${noun} Severity`,
  rule_weight: `${noun} Weight`,
});

export function useHumanizedTypes(documentType) {
  const resolveNoun = () => {
    const dt = typeof documentType === "function" ? documentType() : unref(documentType);
    return ruleTerm(dt).singular;
  };

  function humanizedType(type) {
    const overrides = kindKeyedOverrides(resolveNoun());
    if (type in overrides) {
      return overrides[type];
    }
    if (type in HUMANIZED_TYPES) {
      return HUMANIZED_TYPES[type];
    }
    return type;
  }

  return { humanizedType, humanizedTypes: HUMANIZED_TYPES };
}
