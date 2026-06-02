// API convention (gold standard):
// - ALL mutation functions WRAP in domain key: fn(id, data) → api.put(url, { resource: data })
// - Callers pass ONLY the data — never the wrapper key (no { component: ... } from callers)
// - Query functions pass params directly: fn(id, params) → api.get(url, { params })
// - FormData uploads pass formData directly (ky auto-detects Content-Type)
// - All functions return a promise resolving to { data, status }
// - Errors throw with error.response = { data, status, headers } (axios-compatible shape)
//
// This module exports an abstraction over the HTTP client. Domain modules
// (reviewsApi, projectsApi, etc.) call api.get/post/put/patch/delete without
// knowing the underlying library. Migrated from axios to ky (2026-06-02)
// for supply chain safety. See: https://github.com/sindresorhus/ky
import ky from "ky";

function getCsrfToken() {
  if (typeof document === "undefined") return null;
  return document.querySelector('meta[name="csrf-token"]')?.content;
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
    afterResponse: [
      ({ response }) => {
        if (response.status === 401 && !window.location.pathname.startsWith("/users/sign_in")) {
          window.location.href = "/users/sign_in";
          return new Response(null, { status: 401 });
        }
      },
    ],
  },
});

async function parseBody(response) {
  return response.headers.get("content-type")?.includes("application/json")
    ? response.json()
    : response.text();
}

async function normalizeResponse(promise) {
  try {
    const response = await promise;
    return { data: await parseBody(response), status: response.status };
  } catch (error) {
    if (error.name === "HTTPError") {
      const data = await parseBody(error.response).catch(() => null);
      const normalized = new Error(error.message);
      normalized.response = { data, status: error.response.status, headers: error.response.headers };
      throw normalized;
    }
    throw error;
  }
}

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

  setHeader: (name, value) => { defaults.headers.common[name] = value; },
  defaults,
  _client: "ky",
};

export default api;
