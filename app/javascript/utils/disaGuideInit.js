import { toggleTheme } from "./colorMode";

function updateIcon() {
  const icon = document.querySelector("#disa-theme-toggle .bi");
  if (!icon) return;
  const dark = document.documentElement.getAttribute("data-bs-theme") === "dark";
  icon.className = "bi " + (dark ? "bi-sun" : "bi-moon");
}

function init() {
  const btn = document.getElementById("disa-theme-toggle");
  if (!btn) return;

  btn.addEventListener("click", function () {
    toggleTheme();
    updateIcon();
  });
  updateIcon();
}

document.addEventListener("turbolinks:load", init);
