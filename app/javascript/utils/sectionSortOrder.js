import { FIELD_DISPLAY_ORDER } from "../composables/ruleFieldConfig";

export function sectionIndex(section) {
  if (section == null) return -1;
  const normalized = section === "content" ? "check_content" : section;
  const idx = FIELD_DISPLAY_ORDER.indexOf(normalized);
  return idx >= 0 ? idx : 998;
}

export function compareBySectionOrder(a, b) {
  const idxA = sectionIndex(a.section);
  const idxB = sectionIndex(b.section);
  if (idxA !== idxB) return idxA - idxB;
  return a.id - b.id;
}
