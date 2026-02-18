import { defineConfig } from "vitest/config";
import vue from "@vitejs/plugin-vue2";
import path from "node:path";

const isCI = !!process.env.CI;

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      // Critical: Vue Test Utils uses CJS, Vitest uses ESM
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
