const STORAGE_KEY = "vulcan-theme";

// The documentation site served at /docs decides its theme pre-paint from its
// generator's own storage key. Mirroring the app's preference there is what
// makes the docs follow the app with no flash of the wrong theme — the docs'
// inline init script reads only this key.
const DOCS_STORAGE_KEY = "vitepress-theme-appearance";

export function getStoredTheme() {
  return localStorage.getItem(STORAGE_KEY);
}

export function setStoredTheme(theme) {
  localStorage.setItem(STORAGE_KEY, theme);
  localStorage.setItem(DOCS_STORAGE_KEY, theme);
}

export function getPreferredTheme() {
  const stored = getStoredTheme();
  if (stored) return stored;
  if (
    typeof window !== "undefined" &&
    typeof window.matchMedia === "function" &&
    window.matchMedia("(prefers-color-scheme: dark)").matches
  ) {
    return "dark";
  }
  return "light";
}

export function applyTheme(theme) {
  document.documentElement.setAttribute("data-bs-theme", theme);
}

export function toggleTheme() {
  const current = document.documentElement.getAttribute("data-bs-theme") || "light";
  const next = current === "dark" ? "light" : "dark";
  applyTheme(next);
  setStoredTheme(next);
  return next;
}

export function initTheme() {
  const stored = getStoredTheme();
  // A preference stored before the docs mirror existed has never been copied
  // over; every page load passes through here, so this catches those readers
  // up. Nothing stored means both surfaces follow the system preference on
  // their own — writing would turn "no preference" into a fixed choice.
  if (stored) {
    localStorage.setItem(DOCS_STORAGE_KEY, stored);
  }
  applyTheme(getPreferredTheme());
}
