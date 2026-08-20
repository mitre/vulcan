import { get as lodashGet, set as lodashSet } from "lodash";

/**
 * Map of searchable field labels to their paths within a rule object.
 * Exported as the engine's contract — consumer field lists must use these keys.
 */
export const FIND_AND_REPLACE_FIELDS = Object.freeze({
  "Status Justification": ["status_justification"],
  Title: ["title"],
  "Artifact Description": ["artifact_description"],
  "Vulnerability Discussion": ["disa_rule_descriptions_attributes", 0, "vuln_discussion"],
  Mitigations: ["disa_rule_descriptions_attributes", 0, "mitigations"],
  Check: ["checks_attributes", 0, "content"],
  Fix: ["fixtext"],
  "Vendor Comments": ["vendor_comments"],
});

/**
 * useFindAndReplace — find-and-replace engine for the rule editor (Vue 2.7)
 *
 * Replaces FindAndReplaceMixin. Pure functions, no reactive state — the
 * consumer owns the search form state; these helpers do the matching,
 * highlighting, and text rebuilding.
 *
 * Intentional fixes over the mixin (documented in the spec):
 *   1. Match scanning is NON-overlapping (advances by the find length),
 *      matching String.replaceAll semantics. The mixin advanced by one
 *      character and produced corrupted text for overlapping matches.
 *   2. Empty find text yields no matches/segments instead of an infinite
 *      indexOf("") loop. (The UI disables the button on empty input, but
 *      the engine must be safe on its own.)
 *
 * @returns {Object} { groupFindResults, getSegments, replaceTextInRule }
 */
export function useFindAndReplace() {
  /**
   * Split a field value into alternating plain / highlighted segments.
   * Original casing is always preserved in segment text.
   *
   * @param {string} value - The field text to scan
   * @param {string} findText - The search term
   * @param {boolean} matchCase - Case-sensitive when true
   * @returns {Array<{text: string, highlighted: boolean}>}
   */
  function getSegments(value, findText, matchCase) {
    if (!findText) {
      return [{ text: value, highlighted: false }];
    }

    const normalizedValue = matchCase ? value : value.toLowerCase();
    const normalizedFind = matchCase ? findText : findText.toLowerCase();

    const matchIndices = [];
    let currentIndex;
    let previousIndex = 0;
    while (true) {
      currentIndex = normalizedValue.indexOf(normalizedFind, previousIndex);
      if (currentIndex < 0) {
        break;
      }
      matchIndices.push(currentIndex);
      // Advance past the whole match — non-overlapping scan.
      previousIndex = currentIndex + normalizedFind.length;
    }

    const segments = [];
    currentIndex = 0;
    matchIndices.forEach((index) => {
      segments.push({ text: value.substring(currentIndex, index), highlighted: false });
      currentIndex = index + findText.length;
      segments.push({ text: value.substring(index, currentIndex), highlighted: true });
    });
    segments.push({ text: value.substring(currentIndex), highlighted: false });
    return segments;
  }

  /**
   * Find matches across rules and group them by rule id.
   *
   * @param {Array<Object>} data - Rules to search
   * @param {string} findText - The search term
   * @param {boolean} matchCase - Case-sensitive when true
   * @param {Array<string>} fields - FIND_AND_REPLACE_FIELDS keys to search
   * @returns {Object} { [ruleId]: { rule_id, results: [{ field, value, segments }] } }
   */
  function groupFindResults(data, findText, matchCase, fields) {
    if (!findText) {
      return {};
    }

    const normalizedFindText = matchCase ? findText : findText.toLowerCase();
    const findResults = {};
    data.forEach((rule) => {
      fields.forEach((key) => {
        const value = lodashGet(rule, FIND_AND_REPLACE_FIELDS[key]);
        let normalizedValue = "";
        if (value) {
          normalizedValue = matchCase ? value : value.toLowerCase();
        }
        if (normalizedValue.includes(normalizedFindText)) {
          const result = {
            field: key,
            value: value,
            segments: getSegments(value, findText, matchCase),
          };
          if (rule.id in findResults) {
            findResults[rule.id].results.push(result);
          } else {
            findResults[rule.id] = {
              rule_id: rule.rule_id,
              results: [result],
            };
          }
        }
      });
    });
    return findResults;
  }

  /**
   * Rebuild a rule field, substituting replacement text for every
   * highlighted segment. Mutates the rule in place via the field path
   * (mixin parity — the consumer passes its local working copy).
   *
   * @param {Object} rule - The rule object to mutate
   * @param {string} field - FIND_AND_REPLACE_FIELDS key
   * @param {Array<{text: string, highlighted: boolean}>} segments - From getSegments
   * @param {string} replaceText - Replacement for highlighted segments
   */
  function replaceTextInRule(rule, field, segments, replaceText) {
    let modifiedText = "";
    segments.forEach((segment) => {
      modifiedText += segment.highlighted ? replaceText : segment.text;
    });
    lodashSet(rule, FIND_AND_REPLACE_FIELDS[field], modifiedText);
  }

  return { groupFindResults, getSegments, replaceTextInRule };
}
