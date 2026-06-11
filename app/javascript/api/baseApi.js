/**
 * Vulcan API client — thin abstraction over ky (HTTP library).
 *
 * Domain modules (reviewsApi, projectsApi, etc.) call the exported
 * api.get/post/put/patch/delete methods without knowing the underlying
 * library. Migrated from axios to ky (2026-06) for supply chain safety.
 *
 * ## Conventions
 *
 * | Pattern | Shape | Example |
 * |---------|-------|---------|
 * | CRUD mutation | `fn(id, data)` → wraps in domain key: `{ resource: data }` | `updateRule(id, { title })` → `PUT { rule: { title } }` |
 * | Lifecycle action | `fn(id, payload)` → flat params, no wrapper | `triageReview(id, { triage_status })` → `PATCH { triage_status }` |
 * | FormData upload | `fn(id, formData)` → passed directly, ky auto-detects Content-Type | `createFromBackup(fd)` → `POST <multipart>` |
 * | Query | `fn(id, params)` → `{ params }` becomes `?key=val` | `getComments(id, { page: 2 })` → `GET ?page=2` |
 *
 * ## Response shape
 *
 * All methods resolve to `{ data, status }`. On HTTP errors (4xx/5xx), ky
 * throws HTTPError which {@link normalizeResponse} catches and reshapes to
 * `error.response = { data, status, headers }` — matching the shape that
 * 38+ `.catch(alertOrNotifyResponse)` callers expect.
 *
 * @module baseApi
 * @see https://github.com/sindresorhus/ky
 */
import ky from "ky";

/** @returns {string|null} CSRF token from `<meta name="csrf-token">`, or null in SSR/test. */
function getCsrfToken() {
  if (typeof document === "undefined") return null;
  return document.querySelector('meta[name="csrf-token"]')?.content;
}

/**
 * afterResponse hook: a 401 on ajax means the session died — Devise
 * timeoutable expiry, or session_limitable kicked this session when the
 * same user signed in elsewhere. RELOAD the page instead of jumping to
 * the sign-in path: the reload is a NAVIGATIONAL request, so Devise's
 * FailureApp sets the cause-specific flash ("session expired" vs
 * "signed in elsewhere" vs "sign in to continue") and stores
 * user_return_to for the post-login redirect. Exported for testability —
 * `loc` is injectable (defaults to window.location).
 *
 * @param {{response: Response}} hookArg - ky afterResponse argument.
 * @param {Location} [loc=window.location] - injectable location.
 */
export function handleSessionExpired({ response }, loc = window.location) {
  if (response.status === 401 && !loc.pathname.startsWith("/users/sign_in")) {
    loc.reload();
  }
}

const client = ky.create({
  credentials: "same-origin",
  headers: { Accept: "application/json" },
  hooks: {
    beforeRequest: [
      ({ request }) => {
        const token = getCsrfToken();
        if (token) request.headers.set("X-CSRF-Token", token);
      },
    ],
    afterResponse: [(hookArg) => handleSessionExpired(hookArg)],
  },
});

/**
 * Parse response body as JSON or text based on Content-Type header.
 * @param {Response} response - Fetch API Response object.
 * @returns {Promise<Object|string>} Parsed JSON object, or raw text for non-JSON responses.
 */
async function parseBody(response) {
  return response.headers.get("content-type")?.includes("application/json")
    ? response.json()
    : response.text();
}

/**
 * Wrap a ky request promise so that:
 *   - Success resolves to `{ data, status }` (parsed via {@link parseBody}).
 *   - ky's HTTPError (4xx/5xx) is caught and reshaped to throw a plain Error
 *     with `error.response = { data, status, headers }`.
 *
 * This keeps the response contract identical to the legacy axios shape that
 * AlertMixin.alertOrNotifyResponse and 38+ `.catch()` callers rely on.
 *
 * @param {Promise<Response>} promise - ky request promise.
 * @returns {Promise<{data: *, status: number}>}
 * @throws {Error} With `.response` property on HTTP errors.
 */
async function normalizeResponse(promise) {
  try {
    const response = await promise;
    return { data: await parseBody(response), status: response.status };
  } catch (error) {
    if (error.name === "HTTPError") {
      const data = await parseBody(error.response).catch(() => null);
      const normalized = new Error(error.message);
      normalized.response = {
        data,
        status: error.response.status,
        headers: error.response.headers,
      };
      throw normalized;
    }
    throw error;
  }
}

/**
 * Build ky request options for a mutation (POST/PUT/PATCH).
 *
 * - **FormData** → `{ body }` (ky auto-sets multipart Content-Type with boundary).
 * - **undefined** → `{}` (bodyless mutations like `reopenReview(id)`).
 * - **anything else** → `{ json }` (ky serializes and sets `application/json`).
 *
 * @param {FormData|Object|undefined} body - Request payload.
 * @param {Object} [config={}] - Extra ky options merged into the result.
 * @returns {Object} ky-compatible request options.
 */
function mutationOpts(body, config = {}) {
  if (body instanceof FormData) return { body, ...config };
  if (body === undefined) return { ...config };
  return { json: body, ...config };
}

// Legacy bridge — test mocks reference api.defaults.headers.common.
const defaults = {
  headers: { common: { "X-CSRF-Token": getCsrfToken(), Accept: "application/json" } },
};

const api = {
  get: (url, config = {}) =>
    normalizeResponse(client.get(url, config.params ? { searchParams: config.params } : {})),

  post: (url, body, config) => normalizeResponse(client.post(url, mutationOpts(body, config))),
  put: (url, body, config) => normalizeResponse(client.put(url, mutationOpts(body, config))),
  patch: (url, body, config) => normalizeResponse(client.patch(url, mutationOpts(body, config))),

  delete: (url, config = {}) =>
    normalizeResponse(client.delete(url, config.data ? { json: config.data } : {})),

  setHeader: (name, value) => {
    defaults.headers.common[name] = value;
  },
  defaults,
  _client: "ky",
};

export default api;
