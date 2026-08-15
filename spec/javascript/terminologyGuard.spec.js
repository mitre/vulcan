import { describe, it, expect } from "vitest";
import fs from "node:fs";
import path from "node:path";

/**
 * Terminology guard — the JS-side sibling of the Ruby kind-seam guard spec.
 *
 * REQUIREMENT (deployment-configurable terminology): every user-facing
 * entity-noun string ("rule"/"requirement") must read the central table in
 * constants/terminology.js — never a hardcoded literal. A hardcoded noun is
 * invisible to per-component specs until someone mounts that exact state,
 * which is how six review rounds each found stragglers.
 *
 * EXACT SCOPE (no more, no less):
 *  - template text nodes (moustaches and tag spans masked);
 *  - EVERY static attribute value in templates (tooltip=, description=,
 *    title=, placeholder=, anything) — bound attributes resolve at runtime
 *    through the central table and are covered by component specs;
 *  - string literals in <script> blocks and standalone .js files
 *    (comments stripped) — tooltip maps and error strings render to users.
 * PROSE HEURISTIC: only strings containing a space are considered — a
 * single-word literal ("rule" as an emit name, a CSS token, label: "Rule")
 * is code-shaped and out of scope here; single-word display labels are
 * covered by the component specs and the srg family guard.
 *
 * The allowlist is DIRECTIONAL, not whole-file: each entry permits only the
 * noun direction that is domain-correct there, so a hardcode in the OTHER
 * direction still fails even in an allowlisted file.
 */

const JS_ROOT = path.resolve(__dirname, "../../app/javascript");

const REQUIREMENT_DIRECTION = /(?<![\w-])requirements?(?![\w-])/i;
const RULE_DIRECTION = /(?<![\w-])rules?(?![\w-])/i;
const ANY_NOUN = /(?<![\w-])(rules?|requirements?)(?![\w-])/i;

// file → { allow: the noun direction that is domain-correct there, reason }
const ALLOWED = {
  // SRG-domain copy: "requirement" refers to SRG requirements in the DISA
  // sense on these surfaces (kind chooser, relocation flow, SRG metadata).
  "components/components/DocumentTypePicker.vue": {
    allow: REQUIREMENT_DIRECTION,
    reason: "SRG-domain copy in the kind chooser",
  },
  "components/rules/AcceptRelocationModal.vue": {
    allow: REQUIREMENT_DIRECTION,
    reason: "SRG-only relocation surface",
  },
  "components/rules/DeclineRelocationModal.vue": {
    allow: REQUIREMENT_DIRECTION,
    reason: "SRG-only relocation surface",
  },
  "components/rules/RelocationBacklogPanel.vue": {
    allow: REQUIREMENT_DIRECTION,
    reason: "SRG-only relocation surface",
  },
  "components/rules/RelocationIntakeBanner.vue": {
    allow: REQUIREMENT_DIRECTION,
    reason: "SRG-only relocation surface",
  },
  "components/rules/MarkRelocationModal.vue": {
    allow: REQUIREMENT_DIRECTION,
    reason: "SRG-only relocation surface",
  },
  "components/rules/RuleSecurityRequirementsGuideInformation.vue": {
    allow: REQUIREMENT_DIRECTION,
    reason: "SRG catalog metadata — 'SRG Requirement' is the DISA-domain noun",
  },
  "components/shared/ExportModal.vue": {
    allow: REQUIREMENT_DIRECTION,
    reason: "SRG-domain 'requirements' in satisfied-by copy",
  },
  "components/components/SourceSrgPicker.vue": {
    allow: REQUIREMENT_DIRECTION,
    reason: "SRG-authoring source picker — 'requirements' are SRG requirements",
  },
  // The nesting filter's unavailable-reason deliberately names the SRG kind
  // in SRG terms.
  "constants/ruleFilterRegistry.js": {
    allow: REQUIREMENT_DIRECTION,
    reason: "SRG-domain copy explaining an SRG-kind limitation",
  },
  // Developer precondition throws about the `rule` argument — API-level
  // wording, not display copy.
  "composables/useRuleActions.js": {
    allow: RULE_DIRECTION,
    reason: "null-argument precondition errors name the code parameter",
  },
  // Password complexity rules — the other direction is fine to flag.
  "components/shared/PasswordField.vue": {
    allow: RULE_DIRECTION,
    reason: "password rules, not the entity noun",
  },
  // Deployment-default tables: literal Rule-flavored entries are the
  // documented defaults, kind-shadowed at consumers.
  "composables/useHumanizedTypes.js": {
    allow: RULE_DIRECTION,
    reason: "stig-default humanizer table, kind-shadowed by kindKeyedOverrides",
  },
  // Backend CSV contract: header strings must stay verbatim.
  "constants/csvColumns.js": {
    allow: RULE_DIRECTION,
    reason: "ExportConstants::BENCHMARK_CSV_COLUMNS header contract",
  },
};

function listFiles(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return listFiles(full);
    return /\.(vue|js)$/.test(entry.name) ? [full] : [];
  });
}

// Replace a span with spaces, preserving newlines so line numbers survive.
const mask = (s) => s.replace(/[^\n]/g, " ");

const lineAt = (text, index) => text.slice(0, index).split("\n").length;

const isProse = (s) => s.includes(" ") && ANY_NOUN.test(s);

function stripProperNoun(text) {
  return text.replace(/Security Requirements Guides?/g, mask);
}

function scanTemplate(template, offsetLines) {
  const hits = [];
  const clean = stripProperNoun(template.replace(/<!--[\s\S]*?-->/g, mask));

  // Every static attribute value — directives (v-*, @*, :*) hold bound
  // expressions, not rendered text, and are excluded.
  for (const m of clean.matchAll(/[\s"](?!:|v-|@)[a-zA-Z][a-zA-Z-]*="([^"]*)"/gs)) {
    if (isProse(m[1])) {
      hits.push({
        line: offsetLines + lineAt(clean, m.index),
        text: m[0].trim().slice(0, 100),
        value: m[1],
      });
    }
  }

  // Text nodes: mask moustaches, then whole tag spans (">"-in-quotes safe).
  const textOnly = clean
    .replace(/\{\{[\s\S]*?\}\}/g, mask)
    .replace(/<(?:[^>"']|"[^"]*"|'[^']*')*>/g, mask);
  textOnly.split("\n").forEach((line, idx) => {
    if (ANY_NOUN.test(line)) {
      hits.push({ line: offsetLines + idx + 1, text: line.trim().slice(0, 100), value: line });
    }
  });
  return hits;
}

function scanScript(script, offsetLines) {
  const hits = [];
  const clean = stripProperNoun(
    script.replace(/\/\*[\s\S]*?\*\//g, mask).replace(/\/\/[^\n]*/g, mask),
  );
  // Quoted string literals; template-literal interpolations are REMOVED
  // (not space-masked) so `/rules/${id}` stays a single code token and a
  // converted `... ${ruleTerm(dt).plural} ...` string carries no literal
  // noun. Line numbers are computed on the same collapsed text; a rare
  // multi-line interpolation may shift them by its line count.
  const noInterp = clean.replace(/\$\{[^}]*\}/g, "");
  for (const m of noInterp.matchAll(/"([^"\n]*)"|'([^'\n]*)'|`([^`]*)`/gs)) {
    const value = m[1] ?? m[2] ?? m[3];
    if (isProse(value)) {
      hits.push({
        line: offsetLines + lineAt(noInterp, m.index),
        text: m[0].trim().slice(0, 100),
        value,
      });
    }
  }
  return hits;
}

function scanFile(file) {
  const source = fs.readFileSync(file, "utf8");
  if (file.endsWith(".js")) return scanScript(source, 0);

  const hits = [];
  const tplStart = source.search(/<template[^>]*>/);
  const tplEnd = source.lastIndexOf("</template>");
  if (tplStart !== -1 && tplEnd !== -1) {
    const openEnd = source.indexOf(">", tplStart) + 1;
    hits.push(...scanTemplate(source.slice(openEnd, tplEnd), lineAt(source, openEnd) - 1));
  }
  const scriptMatch = source.match(/<script[^>]*>([\s\S]*?)<\/script>/);
  if (scriptMatch) {
    hits.push(...scanScript(scriptMatch[1], lineAt(source, scriptMatch.index) - 1));
  }
  return hits;
}

describe("terminology guard", () => {
  it("no rendered prose string hardcodes the entity noun outside its allowed direction", () => {
    const failures = [];
    for (const file of listFiles(JS_ROOT)) {
      const rel = path.relative(JS_ROOT, file);
      if (rel === "constants/terminology.js") continue;
      const allowed = ALLOWED[rel];
      const seen = new Set();
      for (const hit of scanFile(file)) {
        if (seen.has(hit.line)) continue;
        seen.add(hit.line);
        if (allowed && allowed.allow.test(hit.value) && !failsOtherDirection(allowed, hit.value)) {
          continue;
        }
        failures.push(`${rel}:${hit.line}  ${hit.text}`);
      }
    }
    expect(
      failures,
      `Hardcoded entity noun(s) in rendered prose — read them from ` +
        `constants/terminology.js (ruleTerm/messageLabels et al.) or add a ` +
        `justified DIRECTIONAL allowlist entry:\n${failures.join("\n")}`,
    ).toEqual([]);
  });

  it("every allowlist entry still exists (no stale exemptions)", () => {
    for (const rel of Object.keys(ALLOWED)) {
      expect(fs.existsSync(path.join(JS_ROOT, rel)), `${rel} vanished — remove its entry`).toBe(
        true,
      );
    }
  });
});

// An allowlisted file only tolerates its own noun direction: a "rule" in an
// SRG-domain file (or vice versa) still fails.
function failsOtherDirection(allowed, text) {
  const other = allowed.allow === REQUIREMENT_DIRECTION ? RULE_DIRECTION : REQUIREMENT_DIRECTION;
  return other.test(text);
}
