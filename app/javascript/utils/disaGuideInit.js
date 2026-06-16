import { toggleTheme } from "./colorMode";

function init() {
  const btn = document.getElementById("disa-theme-toggle");
  if (!btn || btn.dataset.bound) return;
  btn.dataset.bound = "true";
  btn.addEventListener("click", toggleTheme);
}

document.addEventListener("DOMContentLoaded", init);
