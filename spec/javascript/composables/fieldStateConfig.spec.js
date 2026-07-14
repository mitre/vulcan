/**
 * REQUIREMENTS (write-first — these are the contract, not the implementation):
 *
 * The three-state field model: every form field resolves to exactly one of
 * hidden | readonly | editable, keyed by (documentType x status x tier).
 *
 * 1. STIG EQUIVALENCE — for every STIG status and both tiers, the adapter
 *    output must match today's editor behavior state-for-state:
 *    - fields in the legacy `displayed` list (not disabled)  -> editable
 *    - fields in the legacy `disabled` list                  -> readonly
 *    - legacy `advancedDisplayed` fields                     -> hidden to
 *      authors, editable at publisher tier (interim mapping: the Advanced
 *      Fields checkbox IS the tier switch)
 *    - everything else                                       -> hidden
 *    The expected arrays below are copied literally from the shipped
 *    STATUS_FIELD_CONFIG — they are requirements, not derived values.
 *
 * 2. IA/CCI ABSORPTION — the always-on read-only IA Control / CCI reference
 *    block (previously a custom-display-check template bypass) becomes two
 *    declared config keys, `nist_control_family` and `cci`, readonly in the
 *    rule group at EVERY status, both kinds, both tiers.
 *
 * 3. SRG LIFECYCLE — the decided lifecycle table:
 *    - Not Yet Determined: everything editable (status, title, fix, vuln
 *      discussion, check); severity + IA/CCI visible readonly-inherited;
 *      justification hidden.
 *    - Applicable: identical to NYD.
 *    - Not Applicable: justification shown + editable (required is enforced
 *      server-side); ALL content fields hidden; severity + IA/CCI hidden.
 *    - Publisher tier: severity becomes editable; the CCI identifier (ident)
 *      becomes editable; reference display keys stay readonly.
 *    - vendor_comments and the DISA vendor-metadata block are STIG-only.
 *
 * 4. EXHAUSTIVENESS — unknown documentType or unknown status for a kind
 *    throws (never a silent empty config).
 */
import { describe, it, expect } from "vitest";
import {
  FIELD_CONFIG_BY_DOCUMENT_TYPE,
  resolveFieldStates,
  buildFieldSets,
} from "@/composables/fieldStateConfig";

const sorted = (arr) => [...arr].sort();

// Expected legacy STIG shapes (copied from the shipped config — requirements).
const STIG_AUTHOR = {
  "Applicable - Configurable": {
    rule: {
      displayed: ["status", "rule_severity", "title", "fixtext", "vendor_comments"],
      disabled: [],
    },
    disa: { displayed: ["vuln_discussion"], disabled: [] },
    check: { displayed: ["content"], disabled: [] },
  },
  "Not Yet Determined": {
    rule: {
      displayed: ["status", "rule_severity", "title", "fixtext"],
      disabled: ["title", "rule_severity", "fixtext"],
    },
    disa: { displayed: ["vuln_discussion"], disabled: ["vuln_discussion"] },
    check: { displayed: ["content"], disabled: ["content"] },
  },
  "Applicable - Inherently Meets": {
    rule: {
      displayed: [
        "status",
        "rule_severity",
        "status_justification",
        "artifact_description",
        "vendor_comments",
      ],
      disabled: [],
    },
    disa: { displayed: [], disabled: [] },
    check: { displayed: [], disabled: [] },
  },
  "Applicable - Does Not Meet": {
    rule: {
      displayed: ["status", "rule_severity", "status_justification", "vendor_comments"],
      disabled: [],
    },
    disa: {
      displayed: [
        "mitigations_available",
        "mitigations",
        "mitigation_control",
        "poam_available",
        "poam",
      ],
      disabled: [],
    },
    check: { displayed: [], disabled: [] },
  },
  "Not Applicable": {
    rule: {
      displayed: ["status", "rule_severity", "status_justification", "vendor_comments"],
      disabled: ["rule_severity"],
    },
    disa: { displayed: [], disabled: [] },
    check: { displayed: [], disabled: [] },
  },
};

// Legacy advancedDisplayed additions (publisher tier reveals these, editable).
const STIG_PUBLISHER_EXTRA = {
  "Applicable - Configurable": {
    rule: [
      "status_justification",
      "version",
      "rule_weight",
      "artifact_description",
      "fix_id",
      "fixtext_fixref",
      "ident",
      "ident_system",
    ],
    disa: [
      "documentable",
      "false_positives",
      "false_negatives",
      "mitigations_available",
      "mitigations",
      "poam_available",
      "poam",
      "potential_impacts",
      "third_party_tools",
      "mitigation_control",
      "responsibility",
      "ia_controls",
    ],
  },
  "Applicable - Does Not Meet": {
    rule: [],
    disa: [
      "documentable",
      "false_positives",
      "false_negatives",
      "potential_impacts",
      "third_party_tools",
      "responsibility",
      "ia_controls",
    ],
  },
};

// The absorbed reference block: readonly at every status, both kinds/tiers.
const REFERENCE_KEYS = ["nist_control_family", "cci"];

describe("fieldStateConfig — three-state model (kind x status x tier)", () => {
  describe("STIG equivalence (author tier == legacy basic mode)", () => {
    Object.entries(STIG_AUTHOR).forEach(([status, groups]) => {
      it(`${status}: author-tier field sets match the legacy config exactly`, () => {
        const sets = buildFieldSets({ documentType: "stig", status, tier: "author" });
        ["rule", "disa", "check"].forEach((group) => {
          const expectedDisplayed =
            group === "rule"
              ? [...groups[group].displayed, ...REFERENCE_KEYS]
              : groups[group].displayed;
          const expectedDisabled =
            group === "rule"
              ? [...groups[group].disabled, ...REFERENCE_KEYS]
              : groups[group].disabled;
          expect(sorted(sets[group].displayed)).toEqual(sorted(expectedDisplayed));
          expect(sorted(sets[group].disabled)).toEqual(sorted(expectedDisabled));
        });
      });
    });

    it("Applicable - Configurable: publisher tier reveals exactly the legacy advanced fields, editable", () => {
      const sets = buildFieldSets({
        documentType: "stig",
        status: "Applicable - Configurable",
        tier: "publisher",
      });
      const base = STIG_AUTHOR["Applicable - Configurable"];
      const extra = STIG_PUBLISHER_EXTRA["Applicable - Configurable"];
      expect(sorted(sets.rule.displayed)).toEqual(
        sorted([...base.rule.displayed, ...REFERENCE_KEYS, ...extra.rule]),
      );
      expect(sorted(sets.disa.displayed)).toEqual(sorted([...base.disa.displayed, ...extra.disa]));
      // Revealed fields are editable — not in disabled.
      extra.rule.forEach((f) => expect(sets.rule.disabled).not.toContain(f));
      extra.disa.forEach((f) => expect(sets.disa.disabled).not.toContain(f));
    });

    it("Applicable - Does Not Meet: publisher tier reveals exactly the legacy advanced DISA fields", () => {
      const sets = buildFieldSets({
        documentType: "stig",
        status: "Applicable - Does Not Meet",
        tier: "publisher",
      });
      const base = STIG_AUTHOR["Applicable - Does Not Meet"];
      const extra = STIG_PUBLISHER_EXTRA["Applicable - Does Not Meet"];
      expect(sorted(sets.disa.displayed)).toEqual(sorted([...base.disa.displayed, ...extra.disa]));
    });

    it("statuses with no legacy advanced fields are tier-invariant (AIM, NA, NYD)", () => {
      ["Applicable - Inherently Meets", "Not Applicable", "Not Yet Determined"].forEach(
        (status) => {
          const author = buildFieldSets({ documentType: "stig", status, tier: "author" });
          const publisher = buildFieldSets({ documentType: "stig", status, tier: "publisher" });
          expect(publisher).toEqual(author);
        },
      );
    });
  });

  describe("IA/CCI reference absorption", () => {
    it("nist_control_family and cci are readonly in the rule group at every STIG status, both tiers", () => {
      Object.keys(STIG_AUTHOR).forEach((status) => {
        ["author", "publisher"].forEach((tier) => {
          const states = resolveFieldStates({ documentType: "stig", status, tier });
          REFERENCE_KEYS.forEach((key) => {
            expect(states.rule[key]).toBe("readonly");
          });
        });
      });
    });
  });

  describe("SRG lifecycle (the decided table)", () => {
    it("Not Yet Determined: content editable; severity + IA/CCI readonly-inherited; justification hidden", () => {
      const states = resolveFieldStates({
        documentType: "srg",
        status: "Not Yet Determined",
        tier: "author",
      });
      expect(states.rule.status).toBe("editable");
      expect(states.rule.title).toBe("editable");
      expect(states.rule.fixtext).toBe("editable");
      expect(states.disa.vuln_discussion).toBe("editable");
      expect(states.check.content).toBe("editable");
      expect(states.rule.rule_severity).toBe("readonly");
      REFERENCE_KEYS.forEach((key) => expect(states.rule[key]).toBe("readonly"));
      expect(states.rule.status_justification).toBeUndefined();
    });

    it("Applicable: identical to Not Yet Determined (the status records the decision, it does not gate the work)", () => {
      const nyd = resolveFieldStates({
        documentType: "srg",
        status: "Not Yet Determined",
        tier: "author",
      });
      const applicable = resolveFieldStates({
        documentType: "srg",
        status: "Applicable",
        tier: "author",
      });
      expect(applicable).toEqual(nyd);
    });

    it("Not Applicable: justification editable; all content hidden; severity + IA/CCI hidden", () => {
      const states = resolveFieldStates({
        documentType: "srg",
        status: "Not Applicable",
        tier: "author",
      });
      expect(states.rule.status).toBe("editable");
      expect(states.rule.status_justification).toBe("editable");
      expect(states.rule.title).toBeUndefined();
      expect(states.rule.fixtext).toBeUndefined();
      expect(states.disa.vuln_discussion).toBeUndefined();
      expect(states.check.content).toBeUndefined();
      expect(states.rule.rule_severity).toBeUndefined();
      REFERENCE_KEYS.forEach((key) => expect(states.rule[key]).toBeUndefined());
    });

    it("publisher tier: severity and the CCI identifier become editable; reference display stays readonly", () => {
      ["Not Yet Determined", "Applicable"].forEach((status) => {
        const states = resolveFieldStates({ documentType: "srg", status, tier: "publisher" });
        expect(states.rule.rule_severity).toBe("editable");
        expect(states.rule.ident).toBe("editable");
        REFERENCE_KEYS.forEach((key) => expect(states.rule[key]).toBe("readonly"));
      });
    });

    it("vendor_comments and the DISA vendor-metadata block never appear in SRG mode", () => {
      ["Not Yet Determined", "Applicable", "Not Applicable"].forEach((status) => {
        ["author", "publisher"].forEach((tier) => {
          const states = resolveFieldStates({ documentType: "srg", status, tier });
          expect(states.rule.vendor_comments).toBeUndefined();
          ["mitigations", "poam", "documentable", "false_positives", "ia_controls"].forEach((f) =>
            expect(states.disa[f]).toBeUndefined(),
          );
        });
      });
    });
  });

  describe("exhaustiveness", () => {
    it("unknown documentType throws", () => {
      expect(() =>
        resolveFieldStates({ documentType: "checklist", status: "Applicable", tier: "author" }),
      ).toThrow(/unknown document type/i);
    });

    it("unknown status for the kind throws (STIG status against SRG kind)", () => {
      expect(() =>
        resolveFieldStates({
          documentType: "srg",
          status: "Applicable - Configurable",
          tier: "author",
        }),
      ).toThrow(/unknown status/i);
    });

    it("unknown tier throws", () => {
      expect(() =>
        resolveFieldStates({ documentType: "stig", status: "Not Applicable", tier: "root" }),
      ).toThrow(/unknown tier/i);
    });

    it("the config declares exactly the two kinds and their exact vocabularies", () => {
      expect(sorted(Object.keys(FIELD_CONFIG_BY_DOCUMENT_TYPE))).toEqual(["srg", "stig"]);
      expect(sorted(Object.keys(FIELD_CONFIG_BY_DOCUMENT_TYPE.stig))).toEqual(
        sorted(Object.keys(STIG_AUTHOR)),
      );
      expect(sorted(Object.keys(FIELD_CONFIG_BY_DOCUMENT_TYPE.srg))).toEqual(
        sorted(["Not Yet Determined", "Applicable", "Not Applicable"]),
      );
    });
  });
});
