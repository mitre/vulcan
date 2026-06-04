import { useThemeStore } from "../stores/theme";
import { sharedPinia } from "../lib/createVulcanApp";

function updateIcon(isDark) {
  const icon = document.querySelector("#disa-theme-toggle .bi");
  if (!icon) return;
  icon.className = "bi " + (isDark ? "bi-sun" : "bi-moon");
}

function init() {
  const btn = document.getElementById("disa-theme-toggle");
  if (!btn) return;

  const store = useThemeStore(sharedPinia);
  updateIcon(store.isDark);

  store.$subscribe((_mutation, state) => {
    updateIcon(state.isDark);
  });

  btn.addEventListener("click", function () {
    store.toggle();
  });
}

document.addEventListener("turbolinks:load", init);
