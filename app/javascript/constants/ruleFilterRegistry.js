/**
 * Single source of truth for the requirement sidebar's filters and display
 * toggles.
 *
 * Before this registry, one toggle was declared in four unsynchronized
 * places — the default filter shape, the filter bar's rendered rows, the
 * filtering pipeline, and the persistence allowlist — and nothing kept them
 * in agreement. Each document-kind change drifted them further apart: one
 * toggle silently stopped persisting because it was missing from a list, and
 * another silently did nothing on authored requirements while still looking
 * functional.
 *
 * The three groups are NOT symmetric, which is why they live in one module
 * rather than three: STATUS entries are GENERATED from the page's runtime
 * status vocabulary (which differs per document kind and is keyed by status
 * value), while REVIEW and DISPLAY entries are DECLARED. What they share —
 * and what kept drifting — is the entry contract below.
 *
 * Entry contract:
 *   key                  state key (or, for status, the status value itself)
 *   label                user-facing text
 *   default              starting value
 *   persisted            survives a reload
 *   kinds                document kinds the entry can act on
 *   countsAsActiveFilter whether it NARROWS the list (vs changing presentation)
 *
 * Consumers READ from here. None may restate a key, label, default,
 * persistence flag, or applicability.
 */

// Document kinds an entry can apply to. A requirement list is either a STIG
// in progress or an authored SRG; entries that act on Rule-shaped payload
// keys cannot apply to authored requirements, which omit them.
export const KINDS = Object.freeze(["stig", "srg"]);

// Non-toggle state that still persists across a reload. Declared here so the
// persistence allowlist has exactly one home.
const PERSISTED_SCALARS = Object.freeze(["search"]);

const DISPLAY_ENTRIES = Object.freeze([
  {
    key: "nestSatisfiedRulesChecked",
    label: "Nest Satisfied",
    default: true,
    persisted: true,
    // Satisfaction is a Rule-shaped relationship. Authored SRG requirement
    // payloads omit the satisfaction keys entirely, so nesting has nothing
    // to act on and must present as unavailable rather than inert.
    kinds: ["stig"],
    countsAsActiveFilter: false,
    unavailableReason:
      "Nesting is unavailable for SRG requirements — they carry no satisfaction relationships.",
  },
  {
    key: "showSRGIdChecked",
    label: "SRG ID",
    default: false,
    persisted: true,
    kinds: ["stig", "srg"],
    countsAsActiveFilter: false,
  },
  {
    key: "sortBySRGIdChecked",
    label: "Sort SRG",
    default: true,
    persisted: true,
    kinds: ["stig", "srg"],
    countsAsActiveFilter: false,
  },
  {
    key: "openCommentsOnly",
    label: "Open Comments Only",
    default: false,
    persisted: true,
    kinds: ["stig", "srg"],
    // Sits in the display group but NARROWS the list, so it counts as an
    // active filter. That distinction previously lived in scattered
    // conditionals that disagreed with each other.
    countsAsActiveFilter: true,
  },
]);

const REVIEW_ENTRIES = Object.freeze([
  {
    key: "nurFilterChecked",
    label: "Not Under Review",
    default: false,
    persisted: true,
    kinds: ["stig", "srg"],
    countsAsActiveFilter: true,
  },
  {
    key: "urFilterChecked",
    label: "Under Review",
    default: false,
    persisted: true,
    kinds: ["stig", "srg"],
    countsAsActiveFilter: true,
  },
  {
    key: "lckFilterChecked",
    label: "Locked",
    default: false,
    persisted: true,
    kinds: ["stig", "srg"],
    countsAsActiveFilter: true,
  },
]);

/**
 * Status entries are generated, never declared: the vocabulary arrives with
 * the page and is already kind-specific, so a status entry is applicable to
 * whichever kind supplied it. The status VALUE is the key — the registry
 * never hardcodes a status name.
 */
function buildStatusEntries(statuses = []) {
  return statuses.map((status) => ({
    key: status,
    label: status,
    default: false,
    persisted: true,
    kinds: [...KINDS],
    countsAsActiveFilter: true,
  }));
}

export const FILTER_GROUPS = Object.freeze([
  { key: "status", label: "Status", generated: true },
  { key: "display", label: "Display", generated: false },
  { key: "review", label: "Review", generated: false },
]);

/** Entries for one group. Status requires the page's vocabulary. */
export function groupEntries(groupKey, statuses = []) {
  switch (groupKey) {
    case "status":
      return buildStatusEntries(statuses);
    case "display":
      return [...DISPLAY_ENTRIES];
    case "review":
      return [...REVIEW_ENTRIES];
    default:
      return [];
  }
}

/** Every declared (non-status) entry, in group order. */
function declaredEntries() {
  return [...DISPLAY_ENTRIES, ...REVIEW_ENTRIES];
}

/**
 * The default filter state: status defaults nested under statusFilters
 * (keyed by status value), every declared entry flat alongside it.
 */
export function registryDefaults(statuses = []) {
  const statusFilters = {};
  buildStatusEntries(statuses).forEach((entry) => {
    statusFilters[entry.key] = entry.default;
  });

  const defaults = { statusFilters };
  declaredEntries().forEach((entry) => {
    defaults[entry.key] = entry.default;
  });
  return defaults;
}

/**
 * Keys that survive a reload. Status filters persist as a map and are
 * restored separately by value; these are the flat keys.
 */
export function persistedKeys() {
  return [
    ...PERSISTED_SCALARS,
    ...declaredEntries()
      .filter((entry) => entry.persisted)
      .map((entry) => entry.key),
  ];
}

/**
 * Whether an entry can act on a document kind. Unknown keys are inapplicable
 * rather than assumed applicable — guessing is how a toggle ends up looking
 * functional while doing nothing. Status values are kind-specific by
 * construction (the vocabulary comes from the page), so they are not asked.
 */
export function appliesToKind(key, documentType) {
  const entry = declaredEntries().find((candidate) => candidate.key === key);
  if (!entry) return false;
  return entry.kinds.includes(documentType);
}

/** Whether an entry narrows the list, as opposed to changing presentation. */
export function countsAsActiveFilter(key) {
  const entry = declaredEntries().find((candidate) => candidate.key === key);
  return entry ? entry.countsAsActiveFilter : true;
}

/** The label a consumer should render for a declared entry. */
export function labelFor(key) {
  const entry = declaredEntries().find((candidate) => candidate.key === key);
  return entry ? entry.label : key;
}
