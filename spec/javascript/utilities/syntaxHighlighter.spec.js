import { describe, it, expect } from "vitest";
import { highlightCode, getSupportedLanguages } from "@/utilities/syntaxHighlighter";

/**
 * Syntax Highlighter Utility Tests
 *
 * REQUIREMENTS:
 *
 * 1. highlightCode(code, lang, options):
 *    - Returns HTML with syntax highlighting for supported languages
 *    - Supported languages: bash, ruby, xml, yaml, json, javascript, powershell
 *    - Language aliases resolve to canonical names (sh->bash, yml->yaml, etc.)
 *    - Unsupported languages return escaped plain text in pre/code block
 *    - Null/undefined/empty language returns escaped fallback
 *    - HTML special characters (&, <, >, ", ') are escaped in fallback output
 *    - All output has the "shiki" class on the pre element
 *
 * 2. getSupportedLanguages():
 *    - Returns array of all recognized language identifiers
 *    - Includes both canonical names and aliases
 */
describe("Syntax Highlighter", () => {
  // ==========================================
  // highlightCode — SUPPORTED LANGUAGES
  // ==========================================
  describe("highlightCode with supported languages", () => {
    const supportedCanonical = ["bash", "ruby", "xml", "yaml", "json", "javascript", "powershell"];

    supportedCanonical.forEach((lang) => {
      it(`returns HTML with "shiki" class for ${lang}`, () => {
        const result = highlightCode('echo "hello"', lang);
        expect(result).toContain("shiki");
        expect(result).toContain("<pre");
        expect(result).toContain("<code");
      });
    });

    it("produces highlighted spans for a bash command", () => {
      const result = highlightCode('echo "hello world"', "bash");
      // Shiki produces span elements with style attributes for token coloring
      expect(result).toContain("<span");
      expect(result).toContain("shiki");
    });

    it("produces highlighted output for ruby code", () => {
      const result = highlightCode('puts "hello"', "ruby");
      expect(result).toContain("<span");
      expect(result).toContain("shiki");
    });

    it("produces highlighted output for XML", () => {
      const result = highlightCode("<root><child/></root>", "xml");
      expect(result).toContain("<span");
      expect(result).toContain("shiki");
    });
  });

  // ==========================================
  // highlightCode — LANGUAGE ALIASES
  // ==========================================
  describe("highlightCode with language aliases", () => {
    it('resolves "sh" to bash highlighting', () => {
      const result = highlightCode("ls -la", "sh");
      expect(result).toContain("shiki");
      expect(result).toContain("<span");
    });

    it('resolves "shell" to bash highlighting', () => {
      const result = highlightCode("ls -la", "shell");
      expect(result).toContain("shiki");
      expect(result).toContain("<span");
    });

    it('resolves "zsh" to bash highlighting', () => {
      const result = highlightCode("ls -la", "zsh");
      expect(result).toContain("shiki");
      expect(result).toContain("<span");
    });

    it('resolves "yml" to yaml highlighting', () => {
      const result = highlightCode("key: value", "yml");
      expect(result).toContain("shiki");
      expect(result).toContain("<span");
    });

    it('resolves "js" to javascript highlighting', () => {
      const result = highlightCode("const x = 1", "js");
      expect(result).toContain("shiki");
      expect(result).toContain("<span");
    });

    it('resolves "ps1" to powershell highlighting', () => {
      const result = highlightCode("Get-Process", "ps1");
      expect(result).toContain("shiki");
      expect(result).toContain("<span");
    });

    it('resolves "ps" to powershell highlighting', () => {
      const result = highlightCode("Get-Process", "ps");
      expect(result).toContain("shiki");
      expect(result).toContain("<span");
    });

    it("alias produces same output as canonical name", () => {
      const code = 'echo "test"';
      const fromAlias = highlightCode(code, "sh");
      const fromCanonical = highlightCode(code, "bash");
      expect(fromAlias).toBe(fromCanonical);
    });
  });

  // ==========================================
  // highlightCode — UNSUPPORTED LANGUAGES
  // ==========================================
  describe("highlightCode with unsupported languages", () => {
    it("returns escaped plain text in pre/code for unknown language", () => {
      const result = highlightCode("some code", "cobol");
      expect(result).toContain('<pre class="shiki"');
      expect(result).toContain("<code>");
      expect(result).toContain("some code");
      // Should NOT contain syntax-highlighting spans
      expect(result).not.toContain("<span style=");
    });

    it("returns escaped plain text for made-up language", () => {
      const result = highlightCode("x = 1", "fakeLang");
      expect(result).toContain('<pre class="shiki"');
      expect(result).toContain("<code>");
    });
  });

  // ==========================================
  // highlightCode — NULL/UNDEFINED/EMPTY LANGUAGE
  // ==========================================
  describe("highlightCode with null/undefined/empty language", () => {
    it("returns escaped fallback for null language", () => {
      const result = highlightCode("hello world", null);
      expect(result).toContain('<pre class="shiki"');
      expect(result).toContain("<code>");
      expect(result).toContain("hello world");
    });

    it("returns escaped fallback for undefined language", () => {
      const result = highlightCode("hello world", undefined);
      expect(result).toContain('<pre class="shiki"');
      expect(result).toContain("<code>");
      expect(result).toContain("hello world");
    });

    it("returns escaped fallback for empty string language", () => {
      const result = highlightCode("hello world", "");
      expect(result).toContain('<pre class="shiki"');
      expect(result).toContain("<code>");
      expect(result).toContain("hello world");
    });
  });

  // ==========================================
  // highlightCode — HTML ESCAPING
  // ==========================================
  describe("highlightCode HTML escaping in fallback", () => {
    it("escapes ampersands", () => {
      const result = highlightCode("a & b", "unsupported");
      expect(result).toContain("a &amp; b");
      expect(result).not.toContain("a & b");
    });

    it("escapes less-than signs", () => {
      const result = highlightCode("a < b", "unsupported");
      expect(result).toContain("a &lt; b");
    });

    it("escapes greater-than signs", () => {
      const result = highlightCode("a > b", "unsupported");
      expect(result).toContain("a &gt; b");
    });

    it("escapes double quotes", () => {
      const result = highlightCode('a "b" c', "unsupported");
      expect(result).toContain("a &quot;b&quot; c");
    });

    it("escapes single quotes", () => {
      const result = highlightCode("a 'b' c", "unsupported");
      expect(result).toContain("a &#39;b&#39; c");
    });

    it("escapes all special characters together", () => {
      const result = highlightCode("<div class=\"x\">&'test'</div>", "unsupported");
      expect(result).toContain("&lt;div class=&quot;x&quot;&gt;&amp;&#39;test&#39;&lt;/div&gt;");
    });
  });

  // ==========================================
  // highlightCode — THEME OPTION
  // ==========================================
  describe("highlightCode theme option", () => {
    it("defaults to github-light theme", () => {
      const result = highlightCode("echo hi", "bash");
      // github-light theme has a light background
      expect(result).toContain("shiki");
    });

    it("accepts github-dark theme", () => {
      const result = highlightCode("echo hi", "bash", { theme: "github-dark" });
      expect(result).toContain("shiki");
    });
  });

  // ==========================================
  // getSupportedLanguages
  // ==========================================
  describe("getSupportedLanguages", () => {
    it("returns an array", () => {
      const result = getSupportedLanguages();
      expect(Array.isArray(result)).toBe(true);
    });

    it("includes canonical language names", () => {
      const result = getSupportedLanguages();
      expect(result).toContain("bash");
      expect(result).toContain("ruby");
      expect(result).toContain("powershell");
      expect(result).toContain("xml");
      expect(result).toContain("yaml");
      expect(result).toContain("json");
      expect(result).toContain("javascript");
    });

    it("includes common aliases", () => {
      const result = getSupportedLanguages();
      expect(result).toContain("sh");
      expect(result).toContain("shell");
      expect(result).toContain("yml");
      expect(result).toContain("js");
      expect(result).toContain("ps1");
    });

    it("does not include unsupported languages", () => {
      const result = getSupportedLanguages();
      expect(result).not.toContain("python");
      expect(result).not.toContain("java");
      expect(result).not.toContain("go");
    });
  });
});
