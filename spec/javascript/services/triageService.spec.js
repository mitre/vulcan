import { describe, it, expect, vi, beforeEach } from "vitest";
import axios from "axios";
import { submitTriage, submitAdjudicate, submitAdminAction } from "@/services/triageService";

vi.mock("axios");

describe("triageService", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  describe("submitTriage", () => {
    it("patches /reviews/{id}/triage with payload and returns response", async () => {
      const mockResponse = { data: { review: { id: 42, triage_status: "concur" } } };
      axios.patch.mockResolvedValue(mockResponse);

      const result = await submitTriage(42, { triage_status: "concur" });

      expect(axios.patch).toHaveBeenCalledWith("/reviews/42/triage", { triage_status: "concur" });
      expect(result).toBe(mockResponse);
    });

    it("passes through optional fields like duplicate_of_review_id", async () => {
      axios.patch.mockResolvedValue({ data: {} });

      await submitTriage(7, {
        triage_status: "duplicate",
        duplicate_of_review_id: 99,
        response_comment: "Dup of #99",
      });

      expect(axios.patch).toHaveBeenCalledWith("/reviews/7/triage", {
        triage_status: "duplicate",
        duplicate_of_review_id: 99,
        response_comment: "Dup of #99",
      });
    });

    it("propagates axios errors to caller", async () => {
      const error = new Error("Network error");
      axios.patch.mockRejectedValue(error);

      await expect(submitTriage(1, {})).rejects.toThrow("Network error");
    });
  });

  describe("submitAdjudicate", () => {
    it("patches /reviews/{id}/adjudicate with empty payload", async () => {
      const mockResponse = { data: { review: { id: 10, adjudicated_at: "2026-05-24" } } };
      axios.patch.mockResolvedValue(mockResponse);

      const result = await submitAdjudicate(10);

      expect(axios.patch).toHaveBeenCalledWith("/reviews/10/adjudicate", {});
      expect(result).toBe(mockResponse);
    });
  });

  describe("submitAdminAction", () => {
    it("deletes via /reviews/{id}/admin_destroy for hard-delete", async () => {
      axios.delete.mockResolvedValue({ data: {} });

      await submitAdminAction(5, "hard-delete", { audit_comment: "Removing spam" });

      expect(axios.delete).toHaveBeenCalledWith("/reviews/5/admin_destroy", {
        data: { audit_comment: "Removing spam" },
      });
    });

    it("patches /reviews/{id}/move_to_rule with rule_id for move-to-rule", async () => {
      const mockResponse = { data: { review: { id: 5, rule_id: 99 } } };
      axios.patch.mockResolvedValue(mockResponse);

      const result = await submitAdminAction(5, "move-to-rule", {
        rule_id: 99,
        audit_comment: "Moving to correct rule",
      });

      expect(axios.patch).toHaveBeenCalledWith("/reviews/5/move_to_rule", {
        rule_id: 99,
        audit_comment: "Moving to correct rule",
      });
      expect(result).toBe(mockResponse);
    });

    it("patches admin_withdraw for force-withdraw", async () => {
      axios.patch.mockResolvedValue({ data: {} });

      await submitAdminAction(3, "force-withdraw", { audit_comment: "Admin override" });

      expect(axios.patch).toHaveBeenCalledWith("/reviews/3/admin_withdraw", {
        audit_comment: "Admin override",
      });
    });

    it("patches admin_restore for restore", async () => {
      axios.patch.mockResolvedValue({ data: {} });

      await submitAdminAction(3, "restore", { audit_comment: "Restoring comment" });

      expect(axios.patch).toHaveBeenCalledWith("/reviews/3/admin_restore", {
        audit_comment: "Restoring comment",
      });
    });

    it("throws on unknown action", async () => {
      await expect(submitAdminAction(1, "bogus", {})).rejects.toThrow("Unknown admin action: bogus");
    });
  });
});
