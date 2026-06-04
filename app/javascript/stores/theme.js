import { ref } from "vue";
import { defineStore } from "pinia";
import { getPreferredTheme, applyTheme, setStoredTheme } from "../utils/colorMode";

export const useThemeStore = defineStore("theme", () => {
  const isDark = ref(document.documentElement.getAttribute("data-bs-theme") === "dark");

  function toggle() {
    const next = isDark.value ? "light" : "dark";
    applyTheme(next);
    setStoredTheme(next);
    isDark.value = next === "dark";
  }

  function init() {
    const theme = getPreferredTheme();
    applyTheme(theme);
    isDark.value = theme === "dark";
  }

  return { isDark, toggle, init };
});
