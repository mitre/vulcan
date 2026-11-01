import { defineConfig, devices } from "@playwright/test";
import { resolveTarget } from "./.vitepress/target.mjs";

// Browser tests run against a built site served by `vitepress preview`. Build
// the same target first (VULCAN_DOCS_TARGET, as the docs workflow does), so
// the base path below matches the build being served.
const target = resolveTarget();
const port = 4173;
const baseURL = `http://localhost:${port}${target.base}`;

export default defineConfig({
  testDir: "./e2e",
  forbidOnly: !!process.env.CI,
  reporter: process.env.CI ? [["github"], ["html", { open: "never" }]] : "list",
  use: {
    baseURL,
    trace: "retain-on-failure",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: {
    command: `yarn preview --port ${port}`,
    url: baseURL,
    reuseExistingServer: !process.env.CI,
  },
});
