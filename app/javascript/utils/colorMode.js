const STORAGE_KEY = "vulcan-theme";

export function getStoredTheme() {
  return localStorage.getItem(STORAGE_KEY);
}

export function setStoredTheme(theme) {
  localStorage.setItem(STORAGE_KEY, theme);
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
  applyTheme(getPreferredTheme());
}
