import { describe, it, expect, vi, beforeEach } from "vitest";
import { useRelocations, technologyTokenFromPrefix } from "@/composables/useRelocations";
import {
  getRelocations,
  getRelocationDestinations,
  markRelocation,
  unmarkRelocation,
  dryRunRelocation,
  acceptRelocation,
  declineRelocation,
} from "@/api/rulesApi";

vi.mock("@/api/rulesApi", () => ({
  getRelocations: vi.fn(),
  getRelocationDestinations: vi.fn(),
  markRelocation: vi.fn(),
  unmarkRelocation: vi.fn(),
  dryRunRelocation: vi.fn(),
  acceptRelocation: vi.fn(),
  declineRelocation: vi.fn(),
}));

// REQUIREMENT (relocation proposal state): ONE fetch of visible rows
// feeds all three surfaces — the per-rule badge map (this component's
// rows only), the per-SRG backlog (across components), and the
// open-time prompt count keyed by the interim prefix-derived technology
// token (decision 2026-07-20: token field arrives with minting; until
// then the SRG's token = the prefix's leading alpha segment). The server
// also retains DECLINED proposals in the response for source-author
// visibility — those are NOT open markers: badges, backlog counts, and
// prompts count open proposals only.
const MARKERS = [
  { id: 1, source_rule_id: 11, component_id: 5, target_technology_token: "CTR", declined_at: null },
  {
    id: 2,
    source_rule_id: 22,
    component_id: 5,
    target_technology_token: "GPOS",
    declined_at: null,
  },
  { id: 3, source_rule_id: 33, component_id: 9, target_technology_token: "CTR", declined_at: null },
  {
    id: 4,
    source_rule_id: 44,
    component_id: 5,
    target_technology_token: "CTR",
    declined_at: "2026-07-21 10:00:00 UTC",
    adjudication_rationale: "Covered elsewhere.",
  },
];

describe("technologyTokenFromPrefix", () => {
  it("derives the leading alpha segment of the prefix", () => {
    expect(technologyTokenFromPrefix("CNTR-00")).toBe("CNTR");
    expect(technologyTokenFromPrefix("WALK-00")).toBe("WALK");
  });

  it("is null-safe", () => {
    expect(technologyTokenFromPrefix(null)).toBe(null);
    expect(technologyTokenFromPrefix("")).toBe(null);
  });
});

describe("useRelocations", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    getRelocations.mockResolvedValue({ data: MARKERS });
  });

  it("maps this component's OPEN proposals by source rule id — declined rows are not markers", async () => {
    const { fetchMarkers, markersByRuleId } = useRelocations({ id: 5, prefix: "CNTR-00" });
    await fetchMarkers();

    expect(markersByRuleId.value[11].target_technology_token).toBe("CTR");
    expect(markersByRuleId.value[22].target_technology_token).toBe("GPOS");
    expect(markersByRuleId.value[33]).toBeUndefined();
    expect(markersByRuleId.value[44]).toBeUndefined();
  });

  it("serves the per-SRG backlog of OPEN proposals across components", async () => {
    const { fetchMarkers, backlogFor } = useRelocations({ id: 5, prefix: "CNTR-00" });
    await fetchMarkers();

    expect(backlogFor("CTR").map((m) => m.id)).toEqual([1, 3]);
    expect(backlogFor("GPOS").map((m) => m.id)).toEqual([2]);
  });

  it("counts the open-time prompt from the prefix-derived technology token", async () => {
    const { fetchMarkers, technologyToken, srgBacklogCount } = useRelocations({
      id: 5,
      prefix: "CTR-00",
    });
    await fetchMarkers();

    expect(technologyToken.value).toBe("CTR");
    expect(srgBacklogCount.value).toBe(2);
  });

  it("fetches destination options for the propose picker", async () => {
    getRelocationDestinations.mockResolvedValue({
      data: [{ token: "RCVA", name: "Walkthrough receiving SRG", released: false }],
    });
    const { destinations, fetchDestinations } = useRelocations({ id: 5, prefix: "CNTR-00" });

    await fetchDestinations();

    expect(getRelocationDestinations).toHaveBeenCalled();
    expect(destinations.value).toEqual([
      { token: "RCVA", name: "Walkthrough receiving SRG", released: false },
    ]);
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

  // Adjudication (receiver side): dry-run previews against THIS
  // component with zero refresh; accept and decline terminate the
  // proposal and refresh the marker set.
  it("dry-runs a proposal against this component without refetching", async () => {
    dryRunRelocation.mockResolvedValue({ data: { valid: true } });
    const { dryRun } = useRelocations({ id: 5, prefix: "CTR-00" });

    const preview = await dryRun(3);

    expect(dryRunRelocation).toHaveBeenCalledWith(3, 5);
    expect(preview.data.valid).toBe(true);
    expect(getRelocations).not.toHaveBeenCalled();
  });

  it("accepts a proposal into this component and refreshes the markers", async () => {
    acceptRelocation.mockResolvedValue({ data: {} });
    const { accept } = useRelocations({ id: 5, prefix: "CTR-00" });

    await accept(3);

    expect(acceptRelocation).toHaveBeenCalledWith(3, 5);
    expect(getRelocations).toHaveBeenCalled();
  });

  it("declines a proposal with the rationale and refreshes the markers", async () => {
    declineRelocation.mockResolvedValue({ data: {} });
    const { decline } = useRelocations({ id: 5, prefix: "CTR-00" });

    await decline(3, "Covered elsewhere.");

    expect(declineRelocation).toHaveBeenCalledWith(3, 5, "Covered elsewhere.");
    expect(getRelocations).toHaveBeenCalled();
  });

  it("propagates accept failures to the caller without refetching", async () => {
    acceptRelocation.mockRejectedValue(new Error("422"));
    const { accept } = useRelocations({ id: 5, prefix: "CTR-00" });

    await expect(accept(3)).rejects.toThrow("422");
    expect(getRelocations).not.toHaveBeenCalled();
  });
});
