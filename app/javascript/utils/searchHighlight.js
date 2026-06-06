/**
 * Search field highlighting utilities.
 *
 * Extracted from RuleNavigator to DRY the scroll-to-field and text highlight
 * logic. Used by any component that navigates to and highlights matching
 * content within the rule editor.
 */

const FIELD_MAP = { check: "content" };

/**
 * Scroll to a field element and apply a temporary highlight ring.
 * Optionally highlights matching text within the field.
 *
 * @param {string} backendField - Field name from the search API
 * @param {string} [searchQuery] - Search query to highlight within the field
 */
export function scrollToField(backendField, searchQuery) {
  const fieldName = FIELD_MAP[backendField] || backendField;
  setTimeout(() => {
    const el = document.querySelector(`[data-field-name="${fieldName}"]`);
    if (!el) return;
    el.scrollIntoView({ behavior: "smooth", block: "center" });
    el.classList.add("search-field-highlight");
    el.addEventListener("animationend", () => el.classList.remove("search-field-highlight"), {
      once: true,
    });
    if (searchQuery) {
      highlightTextInElement(el, searchQuery);
    }
  }, 300);
}

/**
 * Highlight matching words within a container element using <mark> tags.
 * Marks auto-remove after 5 seconds.
 *
 * @param {HTMLElement} container - The element to search within
 * @param {string} query - Space-separated search terms (min 2 chars each)
 */
export function highlightTextInElement(container, query) {
  const words = query
    .toLowerCase()
    .split(/\s+/)
    .filter((w) => w.length >= 2);
  if (words.length === 0) return;

  const walker = document.createTreeWalker(container, NodeFilter.SHOW_TEXT, null, false);
  const marks = [];

  while (walker.nextNode()) {
    const node = walker.currentNode;
    const parent = node.parentElement;
    if (!parent || parent.tagName === "TEXTAREA" || parent.tagName === "INPUT") continue;
    if (parent.classList.contains("search-term-mark")) continue;

    const text = node.textContent;
    const lower = text.toLowerCase();

    for (const word of words) {
      let pos = lower.indexOf(word);
      if (pos !== -1) {
        marks.push({ node, pos, len: word.length });
        break;
      }
    }
  }

  for (const { node, pos, len } of marks.reverse()) {
    const range = document.createRange();
    range.setStart(node, pos);
    range.setEnd(node, pos + len);
    const mark = document.createElement("mark");
    mark.className = "search-term-mark";
    range.surroundContents(mark);
  }

  if (marks.length > 0) {
    setTimeout(() => {
      container.querySelectorAll(".search-term-mark").forEach((m) => {
        const parent = m.parentNode;
        parent.replaceChild(document.createTextNode(m.textContent), m);
        parent.normalize();
      });
    }, 5000);
  }
}

/**
 * Build a searchable text string from a rule object.
 * Concatenates key attributes for full-text search.
 *
 * @param {string} projectPrefix - Component prefix (e.g., "RHEL-09")
 * @param {Object} rule - Rule object with attributes
 * @returns {string} Lowercase searchable text
 */
export function searchTextForRule(projectPrefix, rule) {
  const ruleSearchAttrs = [
    "fixtext",
    "rule_severity",
    "status_justification",
    "title",
    "vendor_comments",
  ];
  const checkDescriptionSearchAttrs = ["content"];
  const disaDescriptionSearchAttrs = ["vuln_discussion"];

  let searchText = `${projectPrefix}-${rule.rule_id}`;
  for (let i = 0; i < ruleSearchAttrs.length; i++) {
    searchText += ` | ${rule[ruleSearchAttrs[i]] || ""}`;
  }
  for (let i = 0; i < checkDescriptionSearchAttrs.length; i++) {
    for (let j = 0; j < rule.checks_attributes.length; j++) {
      searchText += ` | ${rule.checks_attributes[j][checkDescriptionSearchAttrs[i]] || ""}`;
    }
  }
  for (let i = 0; i < disaDescriptionSearchAttrs.length; i++) {
    for (let j = 0; j < rule.disa_rule_descriptions_attributes.length; j++) {
      searchText += ` | ${rule.disa_rule_descriptions_attributes[j][disaDescriptionSearchAttrs[i]] || ""}`;
    }
  }
  return searchText.toLowerCase();
}
