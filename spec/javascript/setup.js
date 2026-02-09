// Suppress BootstrapVue tooltip warnings in jsdom (elements have no dimensions).
// Must be set before importing BootstrapVue — it reads this at module load time.
process.env.BOOTSTRAP_VUE_NO_WARN = "true";

import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import axios from "axios";
import { Wormhole } from "portal-vue";

Vue.use(BootstrapVue);
Vue.use(IconsPlugin);
Vue.config.productionTip = false;

// Disable portal-vue duplicate target tracking for tests.
// Without this, tests that mount BootstrapVue components with toasters/modals
// trigger "[portal-vue]: Target already exists" warnings.
// Reference: https://github.com/LinusBorg/portal-vue/issues/204
Wormhole.trackInstances = false;

// Mock CSRF token meta tag for FormMixin
if (typeof document !== "undefined") {
  const meta = document.createElement("meta");
  meta.setAttribute("name", "csrf-token");
  meta.setAttribute("content", "test-csrf-token");
  document.head.appendChild(meta);
}

// Initialize axios defaults for FormMixin
axios.defaults.headers = axios.defaults.headers || {};
axios.defaults.headers.common = axios.defaults.headers.common || {};

// Fix localStorage for Node 22+ (native localStorage shadows jsdom's).
// Node 22+ provides globalThis.localStorage via --localstorage-file, but without
// a valid file path the native object has no working methods (clear, getItem, etc.).
// This replaces the broken native implementation with a proper in-memory Storage.
if (typeof localStorage === "undefined" || typeof localStorage.clear !== "function") {
  const store = {};
  globalThis.localStorage = {
    getItem: (key) => (key in store ? store[key] : null),
    setItem: (key, value) => {
      store[key] = String(value);
    },
    removeItem: (key) => {
      delete store[key];
    },
    clear: () => {
      Object.keys(store).forEach((key) => delete store[key]);
    },
    key: (index) => Object.keys(store)[index] || null,
    get length() {
      return Object.keys(store).length;
    },
  };
}
