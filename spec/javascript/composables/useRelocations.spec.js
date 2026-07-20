import { describe, it, expect, vi, beforeEach } from "vitest";
import { useRelocations, familyTokenFromPrefix } from "@/composables/useRelocations";
import { getRelocations, markRelocation, unmarkRelocation } from "@/api/rulesApi";

vi.mock("@/api/rulesApi", () => ({
  getRelocations: vi.fn(),
  markRelocation: vi.fn(),
  unmarkRelocation: vi.fn(),
}));

// REQUIREMENT (relocation marker state): ONE fetch of visible pending
// markers feeds all three surfaces — the per-rule badge map (this
// component's rows only), the per-family backlog (across components),
// and the open-time prompt count keyed by the interim prefix-derived
// family token (decision 2026-07-20: token field arrives with minting;
// until then family = the prefix's leading alpha segment).
const MARKERS = [
  { id: 1, source_rule_id: 11, component_id: 5, target_technology_token: "CTR" },
  { id: 2, source_rule_id: 22, component_id: 5, target_technology_token: "GPOS" },
  { id: 3, source_rule_id: 33, component_id: 9, target_technology_token: "CTR" },
];

describe("familyTokenFromPrefix", () => {
  it("derives the leading alpha segment of the prefix", () => {
    expect(familyTokenFromPrefix("CNTR-00")).toBe("CNTR");
    expect(familyTokenFromPrefix("WALK-00")).toBe("WALK");
  });

  it("is null-safe", () => {
    expect(familyTokenFromPrefix(null)).toBe(null);
    expect(familyTokenFromPrefix("")).toBe(null);
  });
});

describe("useRelocations", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    getRelocations.mockResolvedValue({ data: MARKERS });
  });

  it("maps this component's markers by source rule id after fetching", async () => {
    const { fetchMarkers, markersByRuleId } = useRelocations({ id: 5, prefix: "CNTR-00" });
    await fetchMarkers();

    expect(markersByRuleId.value[11].target_technology_token).toBe("CTR");
    expect(markersByRuleId.value[22].target_technology_token).toBe("GPOS");
    expect(markersByRuleId.value[33]).toBeUndefined();
  });

  it("serves the per-family backlog across components", async () => {
    const { fetchMarkers, backlogFor } = useRelocations({ id: 5, prefix: "CNTR-00" });
    await fetchMarkers();

    expect(backlogFor("CTR").map((m) => m.id)).toEqual([1, 3]);
    expect(backlogFor("GPOS").map((m) => m.id)).toEqual([2]);
  });

  it("counts the open-time prompt from the prefix-derived family token", async () => {
    const { fetchMarkers, familyToken, familyBacklogCount } = useRelocations({
      id: 5,
      prefix: "CTR-00",
    });
    await fetchMarkers();

    expect(familyToken.value).toBe("CTR");
    expect(familyBacklogCount.value).toBe(2);
  });

  it("marks a requirement and refreshes the markers", async () => {
    markRelocation.mockResolvedValue({ data: {} });
    const { mark } = useRelocations({ id: 5, prefix: "CTR-00" });

    await mark(44, "GPOS");

    expect(markRelocation).toHaveBeenCalledWith(44, "GPOS");
    expect(getRelocations).toHaveBeenCalled();
  });

  it("un-marks by record id and refreshes the markers", async () => {
    unmarkRelocation.mockResolvedValue({ data: {} });
    const { unmark } = useRelocations({ id: 5, prefix: "CTR-00" });

    await unmark(1);

    expect(unmarkRelocation).toHaveBeenCalledWith(1);
    expect(getRelocations).toHaveBeenCalled();
  });

  it("propagates mark failures to the caller without refetching", async () => {
    const error = new Error("422");
    markRelocation.mockRejectedValue(error);
    const { mark } = useRelocations({ id: 5, prefix: "CTR-00" });

    await expect(mark(44, "GPOS")).rejects.toThrow("422");
    expect(getRelocations).not.toHaveBeenCalled();
  });
});
