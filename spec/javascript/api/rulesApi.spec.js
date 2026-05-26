import { describe, it, expect, vi, beforeEach } from "vitest";
import api from "@/api/baseApi";
import {
  getRule,
  updateRule,
  deleteRule,
  createRuleInComponent,
  revertRule,
  updateSectionLocks,
  addSatisfaction,
  removeSatisfaction,
  getRulesPicker,
  findInComponent,
  duplicateRule,
} from "@/api/rulesApi";

vi.mock("@/api/baseApi", () => ({
  default: { get: vi.fn(), post: vi.fn(), put: vi.fn(), patch: vi.fn(), delete: vi.fn() },
}));

describe("rulesApi", () => {
  beforeEach(() => vi.resetAllMocks());

  it("getRule calls GET /rules/:id", async () => {
    api.get.mockResolvedValue({ data: {} });
    await getRule(5);
    expect(api.get).toHaveBeenCalledWith("/rules/5");
  });

  it("updateRule wraps data in { rule: data }", async () => {
    api.put.mockResolvedValue({ data: {} });
    await updateRule(5, { status: "Applicable" });
    expect(api.put).toHaveBeenCalledWith("/rules/5", { rule: { status: "Applicable" } });
  });

  it("deleteRule calls DELETE /rules/:id", async () => {
    api.delete.mockResolvedValue({ data: {} });
    await deleteRule(5);
    expect(api.delete).toHaveBeenCalledWith("/rules/5");
  });

  it("createRuleInComponent calls POST /components/:id/rules", async () => {
    api.post.mockResolvedValue({ data: {} });
    await createRuleInComponent(10, { status: "NYD" });
    expect(api.post).toHaveBeenCalledWith("/components/10/rules", { rule: { status: "NYD" } });
  });

  it("revertRule calls POST /rules/:id/revert", async () => {
    api.post.mockResolvedValue({ data: {} });
    await revertRule(5, { version: 2 });
    expect(api.post).toHaveBeenCalledWith("/rules/5/revert", { version: 2 });
  });

  it("updateSectionLocks calls PATCH /rules/:id/section_locks", async () => {
    api.patch.mockResolvedValue({ data: {} });
    await updateSectionLocks(5, { section: "Check", locked: true });
    expect(api.patch).toHaveBeenCalledWith("/rules/5/section_locks", {
      section: "Check",
      locked: true,
    });
  });

  it("addSatisfaction calls POST /rule_satisfactions", async () => {
    api.post.mockResolvedValue({ data: {} });
    await addSatisfaction(1, 2);
    expect(api.post).toHaveBeenCalledWith("/rule_satisfactions", {
      rule_id: 1,
      satisfied_by_rule_id: 2,
    });
  });

  it("removeSatisfaction calls DELETE /rule_satisfactions/:id", async () => {
    api.delete.mockResolvedValue({ data: {} });
    await removeSatisfaction(1, 2);
    expect(api.delete).toHaveBeenCalledWith("/rule_satisfactions/1", {
      data: { rule_id: 1, satisfied_by_rule_id: 2 },
    });
  });

  it("getRulesPicker calls GET /components/:id/rules_picker", async () => {
    api.get.mockResolvedValue({ data: {} });
    await getRulesPicker(10);
    expect(api.get).toHaveBeenCalledWith("/components/10/rules_picker");
  });

  it("findInComponent calls POST /components/:id/find", async () => {
    api.post.mockResolvedValue({ data: {} });
    await findInComponent(10, "search text");
    expect(api.post).toHaveBeenCalledWith("/components/10/find", { find: "search text" });
  });

  it("duplicateRule calls POST /rules/:id/duplicate with rule data", async () => {
    api.post.mockResolvedValue({ data: {} });
    await duplicateRule(5, { title: "Copy of rule" });
    expect(api.post).toHaveBeenCalledWith("/rules/5/duplicate", { rule: { title: "Copy of rule" } });
  });
});
