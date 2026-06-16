import { describe, it, expect, vi, beforeEach } from "vitest";
import api from "@/api/baseApi";
import {
  createRuleReview,
  createComponentReview,
  getReviewResponses,
  updateReviewSection,
  reopenReview,
  getReviewReactions,
  triageReview,
  adjudicateReview,
  withdrawReview,
  adminWithdrawReview,
  adminRestoreReview,
  moveReviewToRule,
  adminDestroyReview,
  toggleReaction,
  updateReview,
  bulkTriageReviews,
  mergeReviews,
} from "@/api/reviewsApi";

vi.mock("@/api/baseApi", () => ({
  default: { get: vi.fn(), post: vi.fn(), put: vi.fn(), patch: vi.fn(), delete: vi.fn() },
}));

describe("reviewsApi", () => {
  beforeEach(() => vi.resetAllMocks());

  it("createRuleReview wraps data in { review: data }", async () => {
    api.post.mockResolvedValue({ data: {} });
    await createRuleReview(5, { action: "comment", comment: "test" });
    expect(api.post).toHaveBeenCalledWith("/rules/5/reviews", {
      review: { action: "comment", comment: "test" },
    });
  });

  it("createComponentReview wraps data in { review: data }", async () => {
    api.post.mockResolvedValue({ data: {} });
    await createComponentReview(10, { action: "comment", comment: "test" });
    expect(api.post).toHaveBeenCalledWith("/components/10/reviews", {
      review: { action: "comment", comment: "test" },
    });
  });

  it("getReviewResponses calls GET /reviews/:id/responses", async () => {
    api.get.mockResolvedValue({ data: { rows: [] } });
    await getReviewResponses(42, { page: 1 });
    expect(api.get).toHaveBeenCalledWith("/reviews/42/responses", { params: { page: 1 } });
  });

  it("getReviewResponses works without params", async () => {
    api.get.mockResolvedValue({ data: { rows: [] } });
    await getReviewResponses(42);
    expect(api.get).toHaveBeenCalledWith("/reviews/42/responses", { params: undefined });
  });

  it("updateReviewSection calls PATCH /reviews/:id/section", async () => {
    api.patch.mockResolvedValue({ data: {} });
    await updateReviewSection(10, "check_content", "Fixing section");
    expect(api.patch).toHaveBeenCalledWith("/reviews/10/section", {
      section: "check_content",
      audit_comment: "Fixing section",
    });
  });

  it("reopenReview calls PATCH /reviews/:id/reopen", async () => {
    api.patch.mockResolvedValue({ data: {} });
    await reopenReview(10);
    expect(api.patch).toHaveBeenCalledWith("/reviews/10/reopen");
  });

  it("getReviewReactions calls GET /reviews/:id/reactions", async () => {
    api.get.mockResolvedValue({ data: {} });
    await getReviewReactions(42, { kind: "up" });
    expect(api.get).toHaveBeenCalledWith("/reviews/42/reactions", { params: { kind: "up" } });
  });

  it("triageReview calls PATCH /reviews/:id/triage with payload", async () => {
    api.patch.mockResolvedValue({ data: {} });
    const payload = { triage_status: "concur", comment: "Agreed" };
    await triageReview(15, payload);
    expect(api.patch).toHaveBeenCalledWith("/reviews/15/triage", payload);
  });

  it("adjudicateReview calls PATCH /reviews/:id/adjudicate with empty payload", async () => {
    api.patch.mockResolvedValue({ data: {} });
    await adjudicateReview(15);
    expect(api.patch).toHaveBeenCalledWith("/reviews/15/adjudicate", {});
  });

  it("withdrawReview calls PATCH /reviews/:id/withdraw", async () => {
    api.patch.mockResolvedValue({ data: {} });
    await withdrawReview(15);
    expect(api.patch).toHaveBeenCalledWith("/reviews/15/withdraw");
  });

  it("adminWithdrawReview calls PATCH /reviews/:id/admin_withdraw with audit_comment", async () => {
    api.patch.mockResolvedValue({ data: {} });
    await adminWithdrawReview(15, "Policy violation");
    expect(api.patch).toHaveBeenCalledWith("/reviews/15/admin_withdraw", {
      audit_comment: "Policy violation",
    });
  });

  it("adminRestoreReview calls PATCH /reviews/:id/admin_restore with audit_comment", async () => {
    api.patch.mockResolvedValue({ data: {} });
    await adminRestoreReview(15, "Restored after review");
    expect(api.patch).toHaveBeenCalledWith("/reviews/15/admin_restore", {
      audit_comment: "Restored after review",
    });
  });

  it("moveReviewToRule calls PATCH /reviews/:id/move_to_rule with rule_id and audit_comment", async () => {
    api.patch.mockResolvedValue({ data: {} });
    await moveReviewToRule(15, 42, "Moving to correct rule");
    expect(api.patch).toHaveBeenCalledWith("/reviews/15/move_to_rule", {
      rule_id: 42,
      audit_comment: "Moving to correct rule",
    });
  });

  it("adminDestroyReview calls DELETE /reviews/:id/admin_destroy with audit_comment in data wrapper", async () => {
    api.delete.mockResolvedValue({ data: {} });
    await adminDestroyReview(15, "Spam removal");
    expect(api.delete).toHaveBeenCalledWith("/reviews/15/admin_destroy", {
      data: { audit_comment: "Spam removal" },
    });
  });

  it("toggleReaction calls POST /reviews/:id/reactions with kind", async () => {
    api.post.mockResolvedValue({ data: { reactions: {} } });
    await toggleReaction(42, "up");
    expect(api.post).toHaveBeenCalledWith("/reviews/42/reactions", { kind: "up" });
  });

  it("updateReview wraps data in { review: data }", async () => {
    api.put.mockResolvedValue({ data: {} });
    await updateReview(15, { comment: "Updated text" });
    expect(api.put).toHaveBeenCalledWith("/reviews/15", {
      review: { comment: "Updated text" },
    });
  });

  it("bulkTriageReviews calls PATCH /reviews/bulk_triage with review_ids and payload", async () => {
    api.patch.mockResolvedValue({ data: {} });
    await bulkTriageReviews([1, 2, 3], { triage_status: "concur" });
    expect(api.patch).toHaveBeenCalledWith("/reviews/bulk_triage", {
      review_ids: [1, 2, 3],
      triage_status: "concur",
    });
  });

  it("mergeReviews calls PATCH /reviews/merge with review_ids and survivor_id", async () => {
    api.patch.mockResolvedValue({ data: {} });
    await mergeReviews([10, 11, 12], 10);
    expect(api.patch).toHaveBeenCalledWith("/reviews/merge", {
      review_ids: [10, 11, 12],
      survivor_id: 10,
    });
  });

  describe("error propagation", () => {
    it("triageReview propagates rejected promise", async () => {
      api.patch.mockRejectedValue(new Error("422 Validation failed"));
      await expect(triageReview(1, {})).rejects.toThrow("422 Validation failed");
    });
  });
});
