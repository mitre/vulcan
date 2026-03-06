/**
 * useRuleAutosave — Debounced autosave composable for rule editing.
 *
 * Saves the rule after 5 seconds of inactivity when enabled.
 * Uses "[Auto-saved]" audit comment for batched activity tracking.
 * Skips save when rule is locked, under review, or toggle is off.
 *
 * @param {Ref<Object>} rule - reactive rule object
 * @param {Object} options - { componentId: Number, delay: Number }
 * @returns { enabled, isDirty, toggle, markDirty, resetTimer, destroy }
 */
import { ref } from "vue";
import axios from "axios";

const DEFAULT_DELAY = 5000; // 5 seconds

export function useRuleAutosave(rule, options = {}) {
  const componentId = options.componentId || 0;
  const delay = options.delay || DEFAULT_DELAY;
  const storageKey = `autosave-${componentId}`;

  // State
  const enabled = ref(localStorage.getItem(storageKey) === "true");
  const isDirty = ref(false);
  let timerId = null;

  function toggle() {
    enabled.value = !enabled.value;
    localStorage.setItem(storageKey, String(enabled.value));
    if (!enabled.value) {
      cancelTimer();
    }
  }

  function markDirty() {
    isDirty.value = true;
    if (enabled.value) {
      scheduleAutoSave();
    }
  }

  function resetTimer() {
    isDirty.value = false;
    cancelTimer();
  }

  function scheduleAutoSave() {
    cancelTimer();
    timerId = setTimeout(() => {
      performAutoSave();
    }, delay);
  }

  function cancelTimer() {
    if (timerId) {
      clearTimeout(timerId);
      timerId = null;
    }
  }

  function performAutoSave() {
    const r = rule.value;
    if (!r || !r.id) return;
    if (!enabled.value) return;
    if (!isDirty.value) return;
    if (r.locked) return;
    if (r.review_requestor_id) return;

    axios
      .put(`/rules/${r.id}`, {
        rule: {
          ...r,
          audit_comment: "[Auto-saved]",
        },
      })
      .then(() => {
        isDirty.value = false;
      })
      .catch(() => {
        // Silently fail — autosave is best-effort
      });
  }

  function destroy() {
    cancelTimer();
  }

  return {
    enabled,
    isDirty,
    toggle,
    markDirty,
    resetTimer,
    destroy,
  };
}
