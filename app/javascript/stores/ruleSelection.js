import { defineStore } from "pinia";
import { ref, computed } from "vue";

export const useRuleSelectionStore = defineStore("ruleSelection", () => {
  const selectedRuleId = ref(null);
  const openRuleIds = ref([]);
  let _router = null;
  let _componentId = null;

  function _readStorage(key, fallback) {
    try {
      const val = localStorage.getItem(key);
      return val !== null ? JSON.parse(val) : fallback;
    } catch {
      return fallback;
    }
  }

  function _writeStorage(key, value) {
    localStorage.setItem(key, JSON.stringify(value));
  }

  function init(router, componentId) {
    _router = router;
    _componentId = componentId;
    selectedRuleId.value = _readStorage(`selectedRuleId-${componentId}`, null);
    openRuleIds.value = _readStorage("openRuleIds", []);
  }

  function selectRule(ruleId) {
    if (ruleId !== null && !openRuleIds.value.includes(ruleId)) {
      openRuleIds.value.push(ruleId);
      _writeStorage("openRuleIds", openRuleIds.value);
    }
    selectedRuleId.value = ruleId;
    _writeStorage(`selectedRuleId-${_componentId}`, ruleId);

    if (_router && ruleId !== null) {
      const current = _router.currentRoute;
      if (current.name !== "rule" || current.params.ruleId !== String(ruleId)) {
        _router.push({ name: "rule", params: { ruleId: String(ruleId) } });
      }
    }
  }

  function deselectRule(ruleId) {
    const idx = openRuleIds.value.indexOf(ruleId);
    if (idx !== -1) {
      openRuleIds.value.splice(idx, 1);
      _writeStorage("openRuleIds", openRuleIds.value);
    }
    if (ruleId === selectedRuleId.value) {
      selectedRuleId.value = null;
      _writeStorage(`selectedRuleId-${_componentId}`, null);
    }
  }

  function closeAllRules() {
    openRuleIds.value = [];
    selectedRuleId.value = null;
    _writeStorage("openRuleIds", []);
    _writeStorage(`selectedRuleId-${_componentId}`, null);
  }

  function isRuleOpen(ruleId) {
    return openRuleIds.value.includes(ruleId);
  }

  function $reset() {
    selectedRuleId.value = null;
    openRuleIds.value = [];
    _router = null;
    _componentId = null;
  }

  return {
    selectedRuleId,
    openRuleIds,
    init,
    selectRule,
    deselectRule,
    closeAllRules,
    isRuleOpen,
    $reset,
  };
});
