import { describe, it, expect } from "vitest";
import {
  FILTER_GROUPS,
  groupEntries,
  registryDefaults,
  persistedKeys,
  appliesToKind,
  countsAsActiveFilter,
} from "@/constants/ruleFilterRegistry";
import { getDefaultFilters } from "@/composables/useRuleFilters";

/**
 * REQUIREMENTS:
 *
 * A sidebar filter or toggle was previously declared in four unsynchronized
 * places — the default filter shape, the filter bar's rendered rows, the
 * filtering pipeline, and the persistence allowlist. Nothing kept them in
 * agreement, so each document-kind change drifted them further apart and
 * produced real defects: open-comments silently failed to persist because it
 * was absent from one of the four lists, and nesting silently did nothing on
 * authored SRG requirements while still looking functional.
 *
 * This registry is the single source of truth for all three groups. The
 * groups are NOT symmetric, and that is why they live in one module rather
 * than three: status entries are GENERATED from the page's runtime status
 * vocabulary (five for stig, three for srg, keyed by status value), while
 * review and display entries are DECLARED. What they share — and what kept
 * drifting — is the entry contract: key, label, default, persistence, kind
 * applicability, and whether the entry counts as an active filter.
 *
 * Every consumer READS from this registry; none may restate any of it.
 */
describe("rule filter registry", () => {
  const STATUSES = ["Applicable", "Not Applicable", "Not Yet Determined"];

  it("declares the three groups in display order", () => {
    expect(FILTER_GROUPS.map((g) => g.key)).toEqual(["status", "display", "review"]);
  });

  it("gives every entry in every group the same contract", () => {
    FILTER_GROUPS.forEach((group) => {
      const entries = groupEntries(group.key, STATUSES);
      expect(entries.length).toBeGreaterThan(0);
      entries.forEach((entry) => {
        expect(typeof entry.key).toBe("string");
        expect(typeof entry.label).toBe("string");
        expect(typeof entry.default).toBe("boolean");
        expect(typeof entry.persisted).toBe("boolean");
        expect(Array.isArray(entry.kinds)).toBe(true);
        expect(entry.kinds.length).toBeGreaterThan(0);
        expect(typeof entry.countsAsActiveFilter).toBe("boolean");
      });
    });
  });

  it("generates status entries from the page's vocabulary rather than declaring them", () => {
    // The vocabulary differs per document kind, so status can never be a
    // static list — but it still stamps into the shared entry contract.
    const stig = groupEntries("status", ["A", "B", "C", "D", "E"]);
    const srg = groupEntries("status", ["A", "B", "C"]);
    expect(stig.length).toBe(5);
    expect(srg.length).toBe(3);
    expect(srg.map((e) => e.key)).toEqual(["A", "B", "C"]);
    srg.forEach((entry) => expect(entry.countsAsActiveFilter).toBe(true));
  });

  it("is the single source of the default filter state", () => {
    // A key present in the registry but missing from the default state — or
    // the reverse — is exactly the divergence this card removes.
    const defaults = getDefaultFilters(STATUSES);
    const fromRegistry = registryDefaults(STATUSES);

    Object.entries(fromRegistry).forEach(([key, value]) => {
      if (key === "statusFilters") {
        expect(defaults.statusFilters).toEqual(value);
        return;
      }
      expect(defaults).toHaveProperty(key);
      expect(defaults[key]).toBe(value);
    });
  });

  it("persists every display toggle, including the one that silently reset", () => {
    // openCommentsOnly was omitted from the old hand-maintained allowlist,
    // so it alone failed to survive a reload.
    const persisted = persistedKeys();
    expect(persisted).toContain("openCommentsOnly");
    expect(persisted).toContain("showSRGIdChecked");
    expect(persisted).toContain("sortBySRGIdChecked");
    expect(persisted).toContain("nestSatisfiedRulesChecked");
  });

  it("knows which entries cannot apply to a document kind", () => {
    // Satisfaction is a STIG-shaped relationship: authored SRG requirement
    // payloads omit the satisfaction keys entirely, so nesting has nothing
    // to act on and must present as unavailable rather than inert.
    expect(appliesToKind("nestSatisfiedRulesChecked", "stig")).toBe(true);
    expect(appliesToKind("nestSatisfiedRulesChecked", "srg")).toBe(false);

    // Identifier display, sorting and comment filtering are kind-agnostic.
    expect(appliesToKind("showSRGIdChecked", "srg")).toBe(true);
    expect(appliesToKind("sortBySRGIdChecked", "srg")).toBe(true);
    expect(appliesToKind("openCommentsOnly", "srg")).toBe(true);
    expect(appliesToKind("lckFilterChecked", "srg")).toBe(true);
  });

  it("treats an unknown key as inapplicable rather than guessing", () => {
    expect(appliesToKind("noSuchToggle", "stig")).toBe(false);
  });

  it("declares which entries count as an active filter, settling the taxonomy", () => {
    // openCommentsOnly sits in the display group but narrows the list, so it
    // counts; the other display toggles change presentation only. That
    // distinction used to live in scattered conditionals that disagreed.
    expect(countsAsActiveFilter("openCommentsOnly")).toBe(true);
    expect(countsAsActiveFilter("showSRGIdChecked")).toBe(false);
    expect(countsAsActiveFilter("sortBySRGIdChecked")).toBe(false);
    expect(countsAsActiveFilter("nestSatisfiedRulesChecked")).toBe(false);
    expect(countsAsActiveFilter("lckFilterChecked")).toBe(true);
  });
});
