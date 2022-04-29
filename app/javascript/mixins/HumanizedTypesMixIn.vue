<script>
// This is meant to be a mixin that provides humanized names for various values.
export default {
  data: function () {
    return {
      humanizedTypes: {
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
        status: "Status",
        title: "Title",
        ident: "Ident",
      },
    };
  },
  methods: {
    humanizedType: function (type) {
      if (type in this.humanizedTypes) {
        return this.humanizedTypes[type];
      }

      return type;
    },
  },
};
</script>
