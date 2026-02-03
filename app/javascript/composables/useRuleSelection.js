import { ref, computed, watch } from "vue";

/**
 * Determines the first "visible" rule for auto-selection.
 * When nesting is enabled in the UI, rules are displayed as:
 *   1. Parents first (rules that have satisfies - they have children nested under them)
 *   2. Standalone leaves (rules with no relationships)
 *   3. Children are hidden from main list (rules that have satisfied_by)
 *
 * This function returns the first rule that would be visible at the top level:
 *   - First parent by version/SRG ID (has satisfies.length > 0), OR
 *   - First standalone by version/SRG ID (no satisfied_by), OR
 *   - Fallback to first rule by version/SRG ID (edge case: all rules are children)
 *
 * Note: Rules are sorted by version (SRG ID) to match the default UI display order
 * (sortBySRGIdChecked: true). Falls back to rule_id if version is missing.
 *
 * @param {Array} rules - Array of rule objects
 * @returns {Object|null} The first visible rule, or null if empty
 */
export function getFirstVisibleRule(rules) {
  if (!rules || rules.length === 0) return null;

  // Sort by version (SRG ID) to match default UI display order
  // Falls back to rule_id for backwards compatibility when version is missing
  const sortedRules = [...rules].sort((a, b) => {
    const aVersion = a.version || "";
    const bVersion = b.version || "";
    // If both have version, sort by version
    if (aVersion && bVersion) {
      return aVersion.localeCompare(bVersion);
    }
    // Fall back to rule_id if version is missing
    const aId = a.rule_id || "";
    const bId = b.rule_id || "";
    return aId.localeCompare(bId);
  });

  // First, try to find a parent (has children nested under it)
  // Parents are shown first when nesting is enabled
  const firstParent = sortedRules.find((r) => r.satisfies?.length > 0);
  if (firstParent) return firstParent;

  // Then, find first standalone (not nested under another rule)
  // These are always visible in the main list
  const firstStandalone = sortedRules.find((r) => !r.satisfied_by?.length);
  if (firstStandalone) return firstStandalone;

  // Fallback to first rule (edge case: all rules are children with no parent in list)
  return sortedRules[0];
}

/**
 * Composable for managing rule selection state.
 * Replaces SelectedRulesMixin with Composition API.
 *
 * @param {Ref<Array>} rules - Reactive ref containing array of rule objects
 * @param {number} componentId - Component ID for localStorage key scoping
 * @param {Object} options - Optional configuration
 * @param {boolean} options.persist - Enable localStorage persistence (default: true)
 * @param {boolean} options.autoSelectFirst - Auto-select first rule if none selected (default: false)
 * @returns {Object} Selection state and methods
 */
export function useRuleSelection(rules, componentId, options = {}) {
  const { persist = true, autoSelectFirst = false } = options;

  // localStorage keys
  const selectedRuleIdKey = `selectedRuleId-${componentId}`;

  // Helper: safely read from localStorage
  function readFromStorage(key, defaultValue) {
    if (!persist) return defaultValue;
    try {
      const stored = localStorage.getItem(key);
      return stored ? JSON.parse(stored) : defaultValue;
    } catch (e) {
      localStorage.removeItem(key);
      return defaultValue;
    }
  }

  // Helper: safely write to localStorage
  function writeToStorage(key, value) {
    if (!persist) return;
    localStorage.setItem(key, JSON.stringify(value));
  }

  // State - initialize from localStorage
  const selectedRuleId = ref(readFromStorage(selectedRuleIdKey, null));
  const openRuleIds = ref(readFromStorage("openRuleIds", []));

  // Computed: Currently selected rule object
  const selectedRule = computed(() => {
    if (selectedRuleId.value === null) {
      return null;
    }

    const foundRule = rules.value.find((rule) => rule.id === selectedRuleId.value);

    if (foundRule) {
      return foundRule;
    }

    // Rule not found - reset selection
    selectedRuleId.value = null;
    return null;
  });

  // Computed: Last editor name from selected rule's histories
  const lastEditor = computed(() => {
    const rule = selectedRule.value;
    if (!rule || !rule.histories || rule.histories.length === 0) {
      return "Unknown User";
    }
    return rule.histories[rule.histories.length - 1].name;
  });

  // Methods
  function selectRule(ruleId) {
    addOpenRule(ruleId);
    selectedRuleId.value = ruleId;
    writeToStorage(selectedRuleIdKey, ruleId);
  }

  function deselectRule(ruleId) {
    removeOpenRule(ruleId);
  }

  function addOpenRule(ruleId) {
    if (ruleId === null || openRuleIds.value.includes(ruleId)) {
      return;
    }
    openRuleIds.value.push(ruleId);
    writeToStorage("openRuleIds", openRuleIds.value);
  }

  function removeOpenRule(ruleId) {
    const index = openRuleIds.value.findIndex((id) => id === ruleId);
    if (index === -1) {
      return;
    }
    openRuleIds.value.splice(index, 1);
    writeToStorage("openRuleIds", openRuleIds.value);

    // Clear selection if closing the currently selected rule
    if (ruleId === selectedRuleId.value) {
      selectedRuleId.value = null;
      writeToStorage(selectedRuleIdKey, null);
    }
  }

  function closeAllRules() {
    openRuleIds.value = [];
    selectedRuleId.value = null;
    writeToStorage("openRuleIds", []);
    writeToStorage(selectedRuleIdKey, null);
  }

  function isRuleOpen(ruleId) {
    return openRuleIds.value.includes(ruleId);
  }

  // Auto-select first visible rule if enabled and no rule is currently selected
  if (autoSelectFirst) {
    watch(
      () => rules.value,
      (newRules) => {
        if (selectedRuleId.value === null && newRules && newRules.length > 0) {
          const firstVisible = getFirstVisibleRule(newRules);
          if (firstVisible) {
            selectRule(firstVisible.id);
          }
        }
      },
      { immediate: true }
    );
  }

  return {
    // State
    selectedRuleId,
    openRuleIds,

    // Computed
    selectedRule,
    lastEditor,

    // Methods
    selectRule,
    deselectRule,
    closeAllRules,
    isRuleOpen,
  };
}
