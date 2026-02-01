import { ref, computed, watch } from "vue";

/**
 * Composable for managing rule selection state.
 * Replaces SelectedRulesMixin with Composition API.
 *
 * @param {Ref<Array>} rules - Reactive ref containing array of rule objects
 * @param {number} componentId - Component ID for localStorage key scoping
 * @param {Object} options - Optional configuration
 * @param {boolean} options.persist - Enable localStorage persistence (default: true)
 * @returns {Object} Selection state and methods
 */
export function useRuleSelection(rules, componentId, options = {}) {
  const { persist = true } = options;

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
