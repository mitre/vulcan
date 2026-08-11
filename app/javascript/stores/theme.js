import { ref } from "vue";
import { defineStore } from "pinia";
import { applyTheme, setStoredTheme, initTheme } from "../utils/colorMode";

export const useThemeStore = defineStore("theme", () => {
  const isDark = ref(document.documentElement.getAttribute("data-bs-theme") === "dark");

  function syncFromDom() {
    isDark.value = document.documentElement.getAttribute("data-bs-theme") === "dark";
  }

  function toggle() {
    const next = isDark.value ? "light" : "dark";
    applyTheme(next);
    setStoredTheme(next);
    isDark.value = next === "dark";
  }

  function init() {
    // initTheme owns page-load behavior: apply the preference AND mirror a
    // stored choice to the documentation site's pre-paint key. Re-inlining
    // its body here is how the mirror once shipped as dead code.
    initTheme();
    syncFromDom();
    const observer = new MutationObserver(syncFromDom);
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-bs-theme"],
    });
  }

  return { isDark, toggle, init };
});
