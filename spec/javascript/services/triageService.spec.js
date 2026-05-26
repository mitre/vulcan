import { describe, it, expect, vi, beforeEach } from "vitest";
import { submitTriage, submitAdjudicate, submitAdminAction } from "@/services/triageService";
import {
  triageReview,
  adjudicateReview,
  adminDestroyReview,
  moveReviewToRule,
  adminWithdrawReview,
  adminRestoreReview,
} from "@/api/reviewsApi";

vi.mock("@/api/reviewsApi", () => ({
  triageReview: vi.fn(() => Promise.resolve({ data: {} })),
  adjudicateReview: vi.fn(() => Promise.resolve({ data: {} })),
  adminDestroyReview: vi.fn(() => Promise.resolve({ data: {} })),
  moveReviewToRule: vi.fn(() => Promise.resolve({ data: {} })),
  adminWithdrawReview: vi.fn(() => Promise.resolve({ data: {} })),
  adminRestoreReview: vi.fn(() => Promise.resolve({ data: {} })),
}));

describe("triageService", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  describe("submitTriage", () => {
    it("delegates to triageReview with reviewId and payload", async () => {
      const mockResponse = { data: { review: { id: 42, triage_status: "concur" } } };
      triageReview.mockResolvedValue(mockResponse);

      const result = await submitTriage(42, { triage_status: "concur" });

      expect(triageReview).toHaveBeenCalledWith(42, { triage_status: "concur" });
      expect(result).toBe(mockResponse);
    });

    it("passes through optional fields like duplicate_of_review_id", async () => {
      triageReview.mockResolvedValue({ data: {} });

      await submitTriage(7, {
        triage_status: "duplicate",
        duplicate_of_review_id: 99,
        response_comment: "Dup of #99",
      });

      expect(triageReview).toHaveBeenCalledWith(7, {
        triage_status: "duplicate",
        duplicate_of_review_id: 99,
        response_comment: "Dup of #99",
      });
    });

    it("propagates errors to caller", async () => {
      const error = new Error("Network error");
      triageReview.mockRejectedValue(error);

      await expect(submitTriage(1, {})).rejects.toThrow("Network error");
    });
  });

  describe("submitAdjudicate", () => {
    it("delegates to adjudicateReview with reviewId", async () => {
      const mockResponse = { data: { review: { id: 10, adjudicated_at: "2026-05-24" } } };
      adjudicateReview.mockResolvedValue(mockResponse);

      const result = await submitAdjudicate(10);

      expect(adjudicateReview).toHaveBeenCalledWith(10);
      expect(result).toBe(mockResponse);
    });
  });

  describe("submitAdminAction", () => {
    it("delegates to adminDestroyReview for hard-delete", async () => {
      adminDestroyReview.mockResolvedValue({ data: {} });

      await submitAdminAction(5, "hard-delete", { audit_comment: "Removing spam" });

      expect(adminDestroyReview).toHaveBeenCalledWith(5, "Removing spam");
    });

    it("delegates to moveReviewToRule for move-to-rule", async () => {
      const mockResponse = { data: { review: { id: 5, rule_id: 99 } } };
      moveReviewToRule.mockResolvedValue(mockResponse);

      const result = await submitAdminAction(5, "move-to-rule", {
        rule_id: 99,
        audit_comment: "Moving to correct rule",
      });

      expect(moveReviewToRule).toHaveBeenCalledWith(5, 99, "Moving to correct rule");
      expect(result).toBe(mockResponse);
    });

    it("delegates to adminWithdrawReview for force-withdraw", async () => {
      adminWithdrawReview.mockResolvedValue({ data: {} });

      await submitAdminAction(3, "force-withdraw", { audit_comment: "Admin override" });

      expect(adminWithdrawReview).toHaveBeenCalledWith(3, "Admin override");
    });

    it("delegates to adminRestoreReview for restore", async () => {
      adminRestoreReview.mockResolvedValue({ data: {} });

      await submitAdminAction(3, "restore", { audit_comment: "Restoring comment" });

      expect(adminRestoreReview).toHaveBeenCalledWith(3, "Restoring comment");
    });

    it("throws on unknown action", async () => {
      await expect(submitAdminAction(1, "bogus", {})).rejects.toThrow("Unknown admin action: bogus");
    });
  });
});
