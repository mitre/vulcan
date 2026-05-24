/**
 * Syntax Highlighter Utility using Shiki
 *
 * Uses the JavaScript RegExp engine for synchronous highlighting
 * without WASM dependencies. This is ideal for browser environments.
 *
 * Supported languages (common in security documentation):
 * - bash/shell (commands)
 * - ruby (InSpec profiles)
 * - powershell (Windows commands)
 * - xml (STIG/SRG data)
 * - yaml (configuration)
 * - json (configuration)
 * - javascript (automation scripts)
 */

import { createHighlighterCoreSync } from "shiki/core";
import { createJavaScriptRegexEngine } from "shiki/engine/javascript";

// Import themes
import githubLight from "@shikijs/themes/github-light";
import githubDark from "@shikijs/themes/github-dark";

// Import languages used in security documentation and STIG authoring.
// Add new imports here + to LANGS array + isLanguageSupported list.
import bash from "@shikijs/langs/bash";
import ruby from "@shikijs/langs/ruby";
import powershell from "@shikijs/langs/powershell";
import xml from "@shikijs/langs/xml";
import yaml from "@shikijs/langs/yaml";
import json from "@shikijs/langs/json";
import javascript from "@shikijs/langs/javascript";
import dockerfile from "@shikijs/langs/dockerfile";
import ini from "@shikijs/langs/ini";
import python from "@shikijs/langs/python";
import hcl from "@shikijs/langs/hcl";
import sql from "@shikijs/langs/sql";
import c from "@shikijs/langs/c";
import go from "@shikijs/langs/go";
import toml from "@shikijs/langs/toml";

const LANGS = [
  bash,
  ruby,
  powershell,
  xml,
  yaml,
  json,
  javascript,
  dockerfile,
  ini,
  python,
  hcl,
  sql,
  c,
  go,
  toml,
];

const LANG_NAMES = LANGS.map((l) => (Array.isArray(l) ? l[0].name : l.name));

const LANGUAGE_ALIASES = {
  sh: "bash",
  shell: "bash",
  zsh: "bash",
  ps1: "powershell",
  ps: "powershell",
  yml: "yaml",
  js: "javascript",
  docker: "dockerfile",
  containerfile: "dockerfile",
  conf: "ini",
  py: "python",
  tf: "hcl",
  terraform: "hcl",
  golang: "go",
};

// Singleton highlighter instance
let highlighterInstance = null;

/**
 * Get or create the highlighter instance (singleton pattern)
 * @returns {Object} Shiki highlighter instance
 */
function getHighlighter() {
  if (!highlighterInstance) {
    highlighterInstance = createHighlighterCoreSync({
      themes: [githubLight, githubDark],
      langs: LANGS,
      engine: createJavaScriptRegexEngine(),
    });
  }
  return highlighterInstance;
}

/**
 * Normalize language identifier
 * @param {string} lang - Language identifier from code block
 * @returns {string} Normalized language name
 */
function normalizeLanguage(lang) {
  if (!lang) return "";
  const normalized = lang.toLowerCase().trim();
  return LANGUAGE_ALIASES[normalized] || normalized;
}

/**
 * Check if a language is supported
 * @param {string} lang - Language identifier
 * @returns {boolean} True if language is supported
 */
function isLanguageSupported(lang) {
  return LANG_NAMES.includes(normalizeLanguage(lang));
}

/**
 * Highlight code with syntax highlighting
 * @param {string} code - Code to highlight
 * @param {string} lang - Language identifier
 * @param {Object} options - Additional options
 * @param {string} options.theme - Theme to use ('github-light' or 'github-dark')
 * @returns {string} HTML string with syntax highlighting
 */
export function highlightCode(code, lang, options = {}) {
  const isDark =
    typeof document !== "undefined" &&
    document.documentElement.getAttribute("data-bs-theme") === "dark";
  const { theme = isDark ? "github-dark" : "github-light" } = options;

  const normalizedLang = normalizeLanguage(lang);

  const fallbackBg = isDark ? "#24292e" : "#f6f8fa";
  const fallbackColor = isDark ? "#e1e4e8" : "#24292e";

  if (!isLanguageSupported(normalizedLang)) {
    const escapedCode = escapeHtml(code);
    return `<pre class="shiki" style="background-color:${fallbackBg};color:${fallbackColor}"><code>${escapedCode}</code></pre>`;
  }

  try {
    const highlighter = getHighlighter();
    return highlighter.codeToHtml(code, {
      lang: normalizedLang,
      theme: theme,
    });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error(`Syntax highlighting failed for language "${lang}":`, error);
    const escapedCode = escapeHtml(code);
    return `<pre class="shiki" style="background-color:${fallbackBg};color:${fallbackColor}"><code>${escapedCode}</code></pre>`;
  }
}

/**
 * Escape HTML special characters
 * @param {string} text - Text to escape
 * @returns {string} Escaped text
 */
function escapeHtml(text) {
  const htmlEscapes = {
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  };
  return text.replaceAll(/[&<>"']/g, (char) => htmlEscapes[char]);
}

/**
 * Get list of supported languages
 * @returns {string[]} Array of supported language identifiers
 */
export function getSupportedLanguages() {
  return [...LANG_NAMES, ...Object.keys(LANGUAGE_ALIASES)];
}

export default {
  highlightCode,
  getSupportedLanguages,
};
