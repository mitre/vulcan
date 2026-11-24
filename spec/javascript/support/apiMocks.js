import { vi } from "vitest";

/**
 * Shared `vi.mock` factories for the API layer.
 *
 * Specs that mount comment or triage components have to stub the same three or
 * four API modules, and the stub bodies were being copied between files.
 *
 * Usage — `vi.mock` is hoisted above imports, so the factory cannot close over
 * a normally imported symbol. The factory body runs lazily, when the mocked
 * module is first requested, so a dynamic import inside it is fine:
 *
 *   vi.mock("@/api/reviewsApi", async () => (await import("@test/support/apiMocks")).reviewsApi());
 *
 * Each factory takes overrides, so a spec can add the endpoints it needs
 * without restating the common ones:
 *
 *   vi.mock("@/api/reviewsApi", async () =>
 *     (await import("@test/support/apiMocks")).reviewsApi({ adjudicateReview: vi.fn() }));
 */

// `resolveWith` undefined gives a bare stub that returns undefined; supplying a
// value gives one that resolves like the real client, `{ data: <value> }`.
function stub(resolveWith) {
  return resolveWith === undefined ? vi.fn() : vi.fn(() => Promise.resolve({ data: resolveWith }));
}

/**
 * The default export of `@/api/baseApi`: the shared client. Pass `resolveWith`
 * when the component under test issues calls the spec does not stub.
 */
export function baseApi({ resolveWith } = {}) {
  return {
    default: {
      get: stub(resolveWith),
      post: stub(resolveWith),
      put: stub(resolveWith),
      patch: stub(resolveWith),
      delete: stub(resolveWith),
      defaults: { headers: { common: {} } },
    },
  };
}

/** `@/api/componentsApi` — the endpoints comment views reach for. */
export function componentsApi(overrides = {}) {
  return { getComments: vi.fn(), ...overrides };
}

/** `@/api/reviewsApi` — the endpoints a comment thread and its actions reach for. */
export function reviewsApi(overrides = {}) {
  return {
    getReviewResponses: vi.fn(),
    createRuleReview: vi.fn(),
    createComponentReview: vi.fn(),
    triageReview: vi.fn(),
    bulkTriageReviews: vi.fn(),
    toggleReaction: vi.fn(),
    ...overrides,
  };
}
