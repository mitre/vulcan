import { defineConfig } from "vitest/config";
import vue from "@vitejs/plugin-vue2";
import path from "node:path";

const isCI = !!process.env.CI;

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      // INVARIANT — do not change this path (root-caused in v2-avw):
      // This alias only applies to vite-processed code (specs + app/javascript).
      // Externalized deps (bootstrap-vue, VTU) resolve bare "vue" through Node,
      // which always yields dist/vue.runtime.common.js (package main/require
      // export — vue's exports map sends ESM imports to a DIFFERENT file).
      // Aliasing to that same CJS file unifies every consumer on ONE Vue
      // module instance. Any other target (e.g. the full build) loads a second
      // Vue runtime for spec/app code and silently breaks BootstrapVue portal
      // rendering (BModal/BTooltip/BPopover content never reaches the DOM).
      // Guarded by "test environment Vue build invariants" in
      // spec/javascript/lib/createVulcanApp.spec.js. Production packs still
      // use the FULL build (esbuild useFullVue: true) for HAML el-compilation
      // — that divergence is asserted via Vue.config.warnHandler in the same
      // spec. SFC templates here are precompiled by vite-plugin-vue2.
      vue: "vue/dist/vue.runtime.common.js",
      "@": path.resolve(__dirname, "app/javascript"),
      "@test": path.resolve(__dirname, "spec/javascript"),
    },
    extensions: [".mjs", ".js", ".ts", ".jsx", ".tsx", ".json", ".vue"],
  },
  css: {
    // Skip PostCSS processing in tests (postcss-import etc. are not installed as devDeps)
    postcss: {},
  },
  test: {
    globals: true,
    environment: "jsdom",
    dir: "spec/javascript",
    include: ["**/*.spec.js"],
    setupFiles: ["./spec/javascript/setup.js"],
    // Worker threads are ~15-20% faster than forks for pure jsdom tests
    pool: "threads",
    // Minimal output in CI, standard locally
    reporters: isCI ? ["dot"] : "default",
    // Coverage configuration for SonarCloud integration
    coverage: {
      provider: "v8",
      reporter: ["lcov"],
      reportsDirectory: "coverage/js",
      include: ["app/javascript/**/*.{js,vue}"],
      exclude: ["app/javascript/packs/**"],
    },
  },
});
