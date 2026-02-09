import { describe, it, expect } from "vitest";
import { buildReviewActions } from "../../../app/javascript/utils/reviewActionHelpers";
import { REVIEW_ACTION_LABELS } from "../../../app/javascript/constants/terminology";

/**
 * Requirements:
 *
 * The buildReviewActions function computes which review actions are available
 * for a given rule based on the user's permissions and the rule's current state.
 * Each action has a `disabledTooltip` that is either null (action enabled) or
 * a string message explaining why the action is disabled.
 *
 * Action-specific rules:
 *
 * request_review:
 *   - Disabled if already under review
 *   - Disabled if rule is locked
 *   - Otherwise enabled
 *
 * revoke_review_request:
 *   - Disabled if user is not admin and not the requestor
 *   - Disabled if rule is not under review
 *   - Otherwise enabled
 *
 * request_changes / approve:
 *   - Disabled if user is not admin and not reviewer
 *   - Disabled if rule is not under review
 *   - Otherwise enabled
 *
 * lock_control:
 *   - Disabled if user is not admin
 *   - Disabled if rule is under review
 *   - Disabled if rule is already locked
 *   - Disabled if status is "Applicable - Does Not Meet" with no mitigations
 *   - Disabled if status is "Applicable - Inherently Meets" with no artifact description
 *   - Otherwise enabled
 *
 * unlock_control:
 *   - Disabled if user is not admin
 *   - Disabled if rule is not locked
 *   - Otherwise enabled
 */

function findAction(actions, value) {
  return actions.find((a) => a.value === value);
}

function makeRule(overrides = {}) {
  return {
    id: 1,
    component_id: 10,
    review_requestor_id: null,
    locked: false,
    status: "Applicable - Configurable",
    disa_rule_descriptions_attributes: [{ mitigations: "some mitigation" }],
    artifact_description: "some artifact",
    ...overrides,
  };
}

describe("buildReviewActions", () => {
  describe("returns all 6 actions", () => {
    it("returns exactly 6 review actions", () => {
      const actions = buildReviewActions(makeRule(), false, "admin", 1);
      expect(actions).toHaveLength(6);
    });

    it("returns actions in correct order", () => {
      const actions = buildReviewActions(makeRule(), false, "admin", 1);
      const values = actions.map((a) => a.value);
      expect(values).toEqual([
        "request_review",
        "revoke_review_request",
        "request_changes",
        "approve",
        "lock_control",
        "unlock_control",
      ]);
    });

    it("includes name and description from labels for each action", () => {
      const actions = buildReviewActions(makeRule(), false, "admin", 1);
      const labels = REVIEW_ACTION_LABELS;

      expect(findAction(actions, "request_review").name).toBe(labels.requestReview.name);
      expect(findAction(actions, "request_review").description).toBe(
        labels.requestReview.description
      );
      expect(findAction(actions, "lock_control").name).toBe(labels.lock.name);
    });
  });

  describe("request_review", () => {
    it("is enabled when rule is not under review and not locked", () => {
      const actions = buildReviewActions(makeRule(), false, "author", 1);
      expect(findAction(actions, "request_review").disabledTooltip).toBeNull();
    });

    it("is disabled when rule is already under review", () => {
      const rule = makeRule({ review_requestor_id: 5 });
      const actions = buildReviewActions(rule, false, "author", 1);
      expect(findAction(actions, "request_review").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.requestReview.alreadyUnderReview
      );
    });

    it("is disabled when rule is locked", () => {
      const rule = makeRule({ locked: true });
      const actions = buildReviewActions(rule, false, "author", 1);
      expect(findAction(actions, "request_review").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.requestReview.isLocked
      );
    });

    it("prioritizes under-review over locked", () => {
      const rule = makeRule({ review_requestor_id: 5, locked: true });
      const actions = buildReviewActions(rule, false, "author", 1);
      expect(findAction(actions, "request_review").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.requestReview.alreadyUnderReview
      );
    });
  });

  describe("revoke_review_request", () => {
    it("is enabled when user is admin and rule is under review", () => {
      const rule = makeRule({ review_requestor_id: 5 });
      const actions = buildReviewActions(rule, false, "admin", 1);
      expect(findAction(actions, "revoke_review_request").disabledTooltip).toBeNull();
    });

    it("is enabled when user is the requestor and rule is under review", () => {
      const rule = makeRule({ review_requestor_id: 42 });
      const actions = buildReviewActions(rule, false, "author", 42);
      expect(findAction(actions, "revoke_review_request").disabledTooltip).toBeNull();
    });

    it("is disabled when user is not admin and not requestor", () => {
      const rule = makeRule({ review_requestor_id: 5 });
      const actions = buildReviewActions(rule, false, "author", 99);
      expect(findAction(actions, "revoke_review_request").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.revokeReview.notAllowed
      );
    });

    it("is disabled when rule is not under review (even if admin)", () => {
      const actions = buildReviewActions(makeRule(), false, "admin", 1);
      expect(findAction(actions, "revoke_review_request").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.revokeReview.notUnderReview
      );
    });

    it("is disabled when readOnly even if otherwise authorized", () => {
      const rule = makeRule({ review_requestor_id: 42 });
      const actions = buildReviewActions(rule, true, "admin", 42);
      expect(findAction(actions, "revoke_review_request").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.revokeReview.notAllowed
      );
    });
  });

  describe("request_changes", () => {
    it("is enabled when user is admin and rule is under review", () => {
      const rule = makeRule({ review_requestor_id: 5 });
      const actions = buildReviewActions(rule, false, "admin", 1);
      expect(findAction(actions, "request_changes").disabledTooltip).toBeNull();
    });

    it("is enabled when user is reviewer and rule is under review", () => {
      const rule = makeRule({ review_requestor_id: 5 });
      const actions = buildReviewActions(rule, false, "reviewer", 1);
      expect(findAction(actions, "request_changes").disabledTooltip).toBeNull();
    });

    it("is disabled when user is author", () => {
      const rule = makeRule({ review_requestor_id: 5 });
      const actions = buildReviewActions(rule, false, "author", 1);
      expect(findAction(actions, "request_changes").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.requestChanges.notAllowed
      );
    });

    it("is disabled when rule is not under review", () => {
      const actions = buildReviewActions(makeRule(), false, "admin", 1);
      expect(findAction(actions, "request_changes").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.requestChanges.notUnderReview
      );
    });
  });

  describe("approve", () => {
    it("is enabled when user is admin and rule is under review", () => {
      const rule = makeRule({ review_requestor_id: 5 });
      const actions = buildReviewActions(rule, false, "admin", 1);
      expect(findAction(actions, "approve").disabledTooltip).toBeNull();
    });

    it("is enabled when user is reviewer and rule is under review", () => {
      const rule = makeRule({ review_requestor_id: 5 });
      const actions = buildReviewActions(rule, false, "reviewer", 1);
      expect(findAction(actions, "approve").disabledTooltip).toBeNull();
    });

    it("is disabled when user is author", () => {
      const rule = makeRule({ review_requestor_id: 5 });
      const actions = buildReviewActions(rule, false, "author", 1);
      expect(findAction(actions, "approve").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.approve.notAllowed
      );
    });

    it("is disabled when rule is not under review", () => {
      const actions = buildReviewActions(makeRule(), false, "reviewer", 1);
      expect(findAction(actions, "approve").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.approve.notUnderReview
      );
    });
  });

  describe("lock_control", () => {
    it("is enabled when admin, not under review, not locked, no validation issues", () => {
      const actions = buildReviewActions(makeRule(), false, "admin", 1);
      expect(findAction(actions, "lock_control").disabledTooltip).toBeNull();
    });

    it("is disabled when user is not admin", () => {
      const actions = buildReviewActions(makeRule(), false, "reviewer", 1);
      expect(findAction(actions, "lock_control").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.lock.notAllowed
      );
    });

    it("is disabled when rule is under review", () => {
      const rule = makeRule({ review_requestor_id: 5 });
      const actions = buildReviewActions(rule, false, "admin", 1);
      expect(findAction(actions, "lock_control").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.lock.underReview
      );
    });

    it("is disabled when rule is already locked", () => {
      const rule = makeRule({ locked: true });
      const actions = buildReviewActions(rule, false, "admin", 1);
      expect(findAction(actions, "lock_control").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.lock.alreadyLocked
      );
    });

    it("is disabled when status is 'Applicable - Does Not Meet' with no mitigations", () => {
      const rule = makeRule({
        status: "Applicable - Does Not Meet",
        disa_rule_descriptions_attributes: [{ mitigations: "" }],
      });
      const actions = buildReviewActions(rule, false, "admin", 1);
      expect(findAction(actions, "lock_control").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.lock.mitigationRequired
      );
    });

    it("is enabled when status is 'Applicable - Does Not Meet' with mitigations present", () => {
      const rule = makeRule({
        status: "Applicable - Does Not Meet",
        disa_rule_descriptions_attributes: [{ mitigations: "Mitigation text" }],
      });
      const actions = buildReviewActions(rule, false, "admin", 1);
      expect(findAction(actions, "lock_control").disabledTooltip).toBeNull();
    });

    it("is disabled when status is 'Applicable - Inherently Meets' with no artifact description", () => {
      const rule = makeRule({
        status: "Applicable - Inherently Meets",
        artifact_description: "",
      });
      const actions = buildReviewActions(rule, false, "admin", 1);
      expect(findAction(actions, "lock_control").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.lock.artifactRequired
      );
    });

    it("is disabled when status is 'Applicable - Inherently Meets' with null artifact description", () => {
      const rule = makeRule({
        status: "Applicable - Inherently Meets",
        artifact_description: null,
      });
      const actions = buildReviewActions(rule, false, "admin", 1);
      expect(findAction(actions, "lock_control").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.lock.artifactRequired
      );
    });

    it("is enabled when status is 'Applicable - Inherently Meets' with artifact description present", () => {
      const rule = makeRule({
        status: "Applicable - Inherently Meets",
        artifact_description: "Artifact text",
      });
      const actions = buildReviewActions(rule, false, "admin", 1);
      expect(findAction(actions, "lock_control").disabledTooltip).toBeNull();
    });

    it("checks conditions in priority order: not admin > under review > locked > mitigation > artifact", () => {
      // Non-admin with all other conditions present - should show notAllowed, not underReview
      const rule = makeRule({ review_requestor_id: 5, locked: true });
      const actions = buildReviewActions(rule, false, "reviewer", 1);
      expect(findAction(actions, "lock_control").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.lock.notAllowed
      );
    });

    it("is disabled when readOnly even with admin permissions", () => {
      const actions = buildReviewActions(makeRule(), true, "admin", 1);
      expect(findAction(actions, "lock_control").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.lock.notAllowed
      );
    });
  });

  describe("unlock_control", () => {
    it("is enabled when admin and rule is locked", () => {
      const rule = makeRule({ locked: true });
      const actions = buildReviewActions(rule, false, "admin", 1);
      expect(findAction(actions, "unlock_control").disabledTooltip).toBeNull();
    });

    it("is disabled when user is not admin", () => {
      const rule = makeRule({ locked: true });
      const actions = buildReviewActions(rule, false, "reviewer", 1);
      expect(findAction(actions, "unlock_control").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.unlock.notAllowed
      );
    });

    it("is disabled when rule is not locked", () => {
      const actions = buildReviewActions(makeRule(), false, "admin", 1);
      expect(findAction(actions, "unlock_control").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.unlock.notLocked
      );
    });
  });

  describe("readOnly mode", () => {
    it("treats readOnly user as non-privileged for all permission-gated actions", () => {
      const rule = makeRule({ review_requestor_id: 5 });
      const actions = buildReviewActions(rule, true, "admin", 1);

      // Admin-only actions should be disabled
      expect(findAction(actions, "lock_control").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.lock.notAllowed
      );
      expect(findAction(actions, "unlock_control").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.unlock.notAllowed
      );

      // Reviewer actions should be disabled
      expect(findAction(actions, "request_changes").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.requestChanges.notAllowed
      );
      expect(findAction(actions, "approve").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.approve.notAllowed
      );

      // Requestor actions should be disabled (readOnly negates requestor)
      expect(findAction(actions, "revoke_review_request").disabledTooltip).toBe(
        REVIEW_ACTION_LABELS.revokeReview.notAllowed
      );
    });
  });
});
