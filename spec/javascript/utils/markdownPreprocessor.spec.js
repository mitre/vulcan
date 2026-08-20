import { describe, it, expect } from "vitest";
import { normalizeListFences } from "@/utilities/markdownPreprocessor";

// Joining arrays of lines keeps triple-backtick fences readable without
// fighting JS template-literal escaping.
const md = (...lines) => lines.join("\n");

describe("normalizeListFences", () => {
  it("indents zero-indent code fence inside numbered list item", () => {
    const input = md("1. Item:", "", "```yaml", "key: val", "```");
    const expected = md("1. Item:", "", "    ```yaml", "    key: val", "    ```");
    expect(normalizeListFences(input)).toBe(expected);
  });

  it("indents code fence inside unordered list item", () => {
    const input = md("- Item:", "", "```bash", "ls -la", "```");
    const expected = md("- Item:", "", "    ```bash", "    ls -la", "    ```");
    expect(normalizeListFences(input)).toBe(expected);
  });

  it("indents nested list item fence to 8 spaces (2nd level)", () => {
    const input = md("- Outer", "  - Inner:", "", "```js", "x = 1", "```");
    const expected = md(
      "- Outer",
      "  - Inner:",
      "",
      "        ```js",
      "        x = 1",
      "        ```",
    );
    expect(normalizeListFences(input)).toBe(expected);
  });

  it("indents fence content and closing fence to match the opening fence", () => {
    const out = normalizeListFences(md("1. Step:", "", "```ruby", "puts 1", "```"));
    const lines = out.split("\n");
    expect(lines).toContain("    ```ruby"); // opening + language tag preserved
    expect(lines).toContain("    puts 1"); // content matches marker
    expect(lines[lines.length - 1]).toBe("    ```"); // closing matches opening
  });

  it("preserves the language tag when indenting", () => {
    const out = normalizeListFences(md("1. x:", "", "```dockerfile", "FROM alpine", "```"));
    expect(out).toContain("    ```dockerfile");
  });

  it("does not double-indent fences already at the correct indent", () => {
    const input = md("1. Item:", "", "    ```yaml", "    key: val", "    ```");
    expect(normalizeListFences(input)).toBe(input);
  });

  it("leaves root-level fences (not in a list) unchanged", () => {
    const input = md("```yaml", "key: val", "```");
    expect(normalizeListFences(input)).toBe(input);
  });

  it("indents every fence when a list item contains multiple fences", () => {
    const input = md("1. Steps:", "", "```bash", "ls", "```", "", "```yaml", "k: v", "```");
    const expected = md(
      "1. Steps:",
      "",
      "    ```bash",
      "    ls",
      "    ```",
      "",
      "    ```yaml",
      "    k: v",
      "    ```",
    );
    expect(normalizeListFences(input)).toBe(expected);
  });

  it("leaves a fence unchanged once the list has ended", () => {
    const input = md("1. Item:", "", "done", "", "```yaml", "k: v", "```");
    expect(normalizeListFences(input)).toBe(input);
  });

  it("returns an empty string for nullish input", () => {
    expect(normalizeListFences(null)).toBe("");
    expect(normalizeListFences(undefined)).toBe("");
    expect(normalizeListFences("")).toBe("");
  });
});
