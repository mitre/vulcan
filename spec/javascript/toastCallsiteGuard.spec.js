import { describe, it, expect } from "vitest";
import fs from "node:fs";
import path from "node:path";

/**
 * Toast call-site guard — companion to the terminology guard.
 *
 * REQUIREMENT (notifier contract): alertOrNotifyResponse takes either a
 * resolved response or the request ERROR itself. It reads the error's
 * .response for HTTP failures — including the RFC 9457 permission-denied
 * branch, which reads the error's OWN .response.status — and .message for
 * transport failures (client timeout, network drop). A call site that
 * unwraps the error first, alertOrNotifyResponse(err.response), silences
 * transport failures entirely (undefined argument, no toast for a real
 * failure), and an `err.response || err` fallback is transport-safe but
 * still silences the permission-denied toast, because a problem-details
 * body carries neither .toast nor .message. The fix is always the same:
 * pass the error unwrapped and let the notifier take it apart.
 *
 * Passing a RESOLVED response (from a .then/await success path) stays
 * legal — a resolved value has no `.response` property to unwrap, so it
 * cannot match the pattern below.
 */

const JS_ROOT = path.resolve(__dirname, "../../app/javascript");

// An identifier followed by `.response` at the argument head: err.response,
// error.response, response.response — and `x.response || x` fallbacks,
// which begin identically.
const INNER_RESPONSE_ARG = /alertOrNotifyResponse\(\s*[A-Za-z_$][\w$]*\.response\b/g;

// file (relative to app/javascript) → reason the matching argument is a
// genuinely resolved response held in a matching-shaped expression, not an
// unwrapped request error. Expected to stay empty; justify every entry.
const ALLOWED = {};

function listFiles(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return listFiles(full);
    return /\.(vue|js)$/.test(entry.name) ? [full] : [];
  });
}

// Replace a span with spaces, preserving newlines so line numbers survive.
const mask = (s) => s.replace(/[^\n]/g, " ");

const stripComments = (text) =>
  text.replace(/\/\*[\s\S]*?\*\//g, mask).replace(/\/\/[^\n]*/g, mask);

const lineAt = (text, index) => text.slice(0, index).split("\n").length;

describe("toast call-site guard", () => {
  it("no call site hands alertOrNotifyResponse an inner response", () => {
    const violations = [];
    for (const file of listFiles(JS_ROOT)) {
      const rel = path.relative(JS_ROOT, file);
      if (ALLOWED[rel]) continue;
      const text = stripComments(fs.readFileSync(file, "utf8"));
      for (const match of text.matchAll(INNER_RESPONSE_ARG)) {
        violations.push(`${rel}:${lineAt(text, match.index)} — ${match[0].trim()}`);
      }
    }
    expect(
      violations,
      `call sites unwrapping the error before alertOrNotifyResponse ` +
        `(pass the error itself — the notifier reads .response/.message):\n` +
        violations.join("\n"),
    ).toEqual([]);
  });

  it("every allowlist entry still exists (no stale exemptions)", () => {
    for (const rel of Object.keys(ALLOWED)) {
      expect(fs.existsSync(path.join(JS_ROOT, rel)), `stale allowlist entry: ${rel}`).toBe(true);
    }
  });
});
