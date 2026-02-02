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

// Import languages commonly used in security documentation
import bash from "@shikijs/langs/bash";
import ruby from "@shikijs/langs/ruby";
import powershell from "@shikijs/langs/powershell";
import xml from "@shikijs/langs/xml";
import yaml from "@shikijs/langs/yaml";
import json from "@shikijs/langs/json";
import javascript from "@shikijs/langs/javascript";

// Language aliases for common variations
const LANGUAGE_ALIASES = {
  sh: "bash",
  shell: "bash",
  zsh: "bash",
  ps1: "powershell",
  ps: "powershell",
  yml: "yaml",
  js: "javascript",
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
      langs: [bash, ruby, powershell, xml, yaml, json, javascript],
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
  const supported = ["bash", "ruby", "powershell", "xml", "yaml", "json", "javascript"];
  return supported.includes(normalizeLanguage(lang));
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
  const { theme = "github-light" } = options;

  const normalizedLang = normalizeLanguage(lang);

  // If language not supported, return escaped code in a pre/code block
  if (!isLanguageSupported(normalizedLang)) {
    const escapedCode = escapeHtml(code);
    return `<pre class="shiki" style="background-color:#fff"><code>${escapedCode}</code></pre>`;
  }

  try {
    const highlighter = getHighlighter();
    return highlighter.codeToHtml(code, {
      lang: normalizedLang,
      theme: theme,
    });
  } catch (error) {
    // Fallback to escaped plain text on error
    // eslint-disable-next-line no-console
    console.error(`Syntax highlighting failed for language "${lang}":`, error);
    const escapedCode = escapeHtml(code);
    return `<pre class="shiki" style="background-color:#fff"><code>${escapedCode}</code></pre>`;
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
  return text.replace(/[&<>"']/g, (char) => htmlEscapes[char]);
}

/**
 * Get list of supported languages
 * @returns {string[]} Array of supported language identifiers
 */
export function getSupportedLanguages() {
  return [
    "bash",
    "shell",
    "sh",
    "ruby",
    "powershell",
    "ps1",
    "xml",
    "yaml",
    "yml",
    "json",
    "javascript",
    "js",
  ];
}

export default {
  highlightCode,
  getSupportedLanguages,
};
