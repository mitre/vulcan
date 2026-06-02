import { describe, it } from "vitest";

const { RuleTester } = require("eslint");
const rule = require("../../../eslint-rules/comment-tracker");

// Wire RuleTester's internal describe/it to Vitest's versions
RuleTester.describe = describe;
RuleTester.it = it;

const ruleTester = new RuleTester({
  parserOptions: { ecmaVersion: 2020, sourceType: "module" },
});

ruleTester.run("comment-tracker", rule, {
  valid: [
    "// This is a normal comment",
    "const x = 1; // another normal comment",
    "// vulcan_audited tracks changes",
    "// See vulcan.default.yml for settings",
  ],

  invalid: [
    {
      code: "// vulcan-v3.x-aik: renamed for clarity",
      output: "// renamed for clarity",
      errors: [{ messageId: "trackerRef" }],
    },
    {
      code: "// vulcan-clean-abc123: fix later",
      output: "// fix later",
      errors: [{ messageId: "trackerRef" }],
    },
    {
      code: "// vulcan-v2.x-def: old reference",
      output: "// old reference",
      errors: [{ messageId: "trackerRef" }],
    },
    {
      code: "const x = 1; // vulcan-v3.x-oxz: peer endpoint",
      output: "const x = 1; // peer endpoint",
      errors: [{ messageId: "trackerRef" }],
    },
    {
      code: "// Batch counts via GROUP BY (vulcan-v3.x-73z.9).",
      output: "// Batch counts via GROUP BY.",
      errors: [{ messageId: "trackerRef" }],
    },
    {
      code: "// vulcan-v3.x-480.7",
      output: "",
      errors: [{ messageId: "trackerRef" }],
    },
  ],
});
