// API convention (gold standard):
// - ALL mutation functions WRAP in domain key: fn(id, data) → api.put(url, { resource: data })
// - Callers pass ONLY the data — never the wrapper key (no { component: ... } from callers)
// - Query functions pass params directly: fn(id, params) → api.get(url, { params })
// - FormData uploads pass formData directly (axios auto-detects Content-Type)
// - All functions return the axios promise (caller chains .then/.catch)
//
// Intentionally NOT covered by this API layer:
// - HTML page routes (settings, triage, disa-guide) — full-page navigation, not JSON
// - Individual search routes (GET /search/components|projects|rules) — globalSearch aggregates all
// - Devise auth routes (sign_in, register, confirm, password) — form POST, not JSON API
import axios from "axios";

if (axios.defaults?.headers?.common) {
  const csrfMeta = document.querySelector('meta[name="csrf-token"]');
  if (csrfMeta) {
    axios.defaults.headers.common["X-CSRF-Token"] = csrfMeta.content;
  }
  axios.defaults.headers.common["Accept"] = "application/json";
}

export default axios;
