/**
 * @fileoverview Detects internal issue-tracker references in source comments.
 *
 * Tracker IDs (e.g. vulcan-clean-abc, vulcan-v3.x-480.7) are project-management
 * artifacts that belong in commit messages and PR descriptions — not in committed
 * source code. They leak internal tooling details into public repositories and
 * become meaningless as boards are reorganized.
 *
 * Auto-fix strips the tracker reference while preserving the surrounding comment.
 * When stripping leaves the comment empty, the entire comment is removed.
 *
 * Designed to be portable across MITRE projects — add new tracker prefixes to
 * TRACKER_RE as needed.
 *
 * @author Vulcan contributors
 * @see {@link https://eslint.org/docs/latest/extend/custom-rules ESLint custom rules}
 * @see Pattern follows ESLint core no-warning-comments (sourceCode.getAllComments)
 */

"use strict";

//------------------------------------------------------------------------------
// Constants
//------------------------------------------------------------------------------

/**
 * Tracker reference source pattern — legacy long-form board prefixes
 * (vulcan-clean-, vulcan-v2.x-, vulcan-v3.x-) AND the current
 * short-form board prefix (v2-, v3-), followed by a card identifier.
 * ONE source string so the matcher and the three strip patterns below
 * cannot drift. Update here when the board prefix changes or when
 * adopting this rule in other projects.
 *
 * @type {string}
 */
const TRACKER_SRC =
  "\\b(?:vulcan-(?:v3\\.x|v2\\.x|clean)|v[23])-[\\w.]+(?:\\s*§[\\d.]+)?";

/**
 * Matches internal tracker prefixes followed by a card identifier.
 *
 * @example
 * // All matched:
 * // vulcan-v3.x-480.7
 * // vulcan-clean-abc123
 * // vulcan-v2.x-def
 * // vulcan-v3.x-480.6 §18.4
 * // v2-abc.12
 *
 * @type {RegExp}
 */
const TRACKER_RE = new RegExp(TRACKER_SRC, "g");

//------------------------------------------------------------------------------
// Helpers
//------------------------------------------------------------------------------

/**
 * Strips tracker patterns from comment text in priority order:
 * parenthesized refs first, then leading refs with colon/comma,
 * then trailing bare refs.
 *
 * @param {string} text - Comment value (without // or /* delimiters)
 * @returns {string} Cleaned text with tracker references removed
 */
function stripTracker(text) {
  return text
    .replace(new RegExp("\\s*\\(" + TRACKER_SRC + "\\)", "g"), "")
    .replace(new RegExp(TRACKER_SRC + "[,:]\\s*", "g"), "")
    .replace(new RegExp("\\s*" + TRACKER_SRC + "\\.?", "g"), "")
    .replace(/  +/g, " ")
    .trimEnd();
}

/**
 * Builds a fixer function for a comment token. Strips the tracker
 * reference and either replaces the comment text (preserving
 * surrounding code) or removes the comment entirely if empty.
 *
 * For line comments: reconstructs as `// cleaned value`
 * For block comments: reconstructs as `/* cleaned value *​/`
 *
 * When the cleaned comment is empty:
 * - Removes leading whitespace on the same line
 * - Removes trailing newline for standalone line comments
 *
 * @param {import('eslint').SourceCode} sourceCode - The file's source code object
 * @param {import('eslint').AST.Token} comment - The comment token to fix
 * @returns {function(import('eslint').Rule.RuleFixer): import('eslint').Rule.Fix}
 */
function buildFixer(sourceCode, comment) {
  return function fix(fixer) {
    const cleaned = stripTracker(comment.value);

    if (cleaned.trim() === "") {
      const text = sourceCode.getText();
      let start = comment.range[0];
      let end = comment.range[1];

      // Remove leading whitespace on the same line
      while (start > 0 && text[start - 1] === " ") start--;

      // Remove trailing newline for line comments
      if (comment.type === "Line" && text[end] === "\n") end++;

      return fixer.removeRange([start, end]);
    }

    if (comment.type === "Line") {
      return fixer.replaceTextRange(comment.range, "//" + cleaned);
    }
    return fixer.replaceTextRange(
      comment.range,
      "/*" + cleaned + "*/"
    );
  };
}

//------------------------------------------------------------------------------
// Rule Definition
//------------------------------------------------------------------------------

/** @type {import('eslint').Rule.RuleModule} */
module.exports = {
  meta: {
    type: "suggestion",
    docs: {
      description:
        "Disallow internal tracker/card IDs in comments. " +
        "Tracker references belong in commit messages, not source code.",
      recommended: false,
    },
    fixable: "code",
    schema: [],
    messages: {
      trackerRef:
        "Do not reference tracker IDs in source comments.",
    },
  },

  create(context) {
    return {
      /**
       * Iterates all comments via sourceCode.getAllComments() — the
       * canonical pattern for comment-scanning rules. Comments are
       * tokens, not AST nodes, so they cannot be visited via normal
       * selectors. This matches ESLint core's no-warning-comments.
       *
       * @returns {void}
       */
      Program() {
        const comments = context.sourceCode.getAllComments();

        for (const comment of comments) {
          TRACKER_RE.lastIndex = 0;
          if (!TRACKER_RE.test(comment.value)) continue;

          context.report({
            node: comment,
            messageId: "trackerRef",
            fix: buildFixer(context.sourceCode, comment),
          });
        }
      },
    };
  },
};
