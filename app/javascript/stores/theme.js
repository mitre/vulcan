import { ref } from "vue";
import { defineStore } from "pinia";
import { getPreferredTheme, applyTheme, setStoredTheme } from "../utils/colorMode";

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
    const theme = getPreferredTheme();
    applyTheme(theme);
    syncFromDom();
    const observer = new MutationObserver(syncFromDom);
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-bs-theme"],
    });
  }

  return { isDark, toggle, init };
});
