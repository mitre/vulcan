// @ts-check
const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    video: 'on',
    screenshot: 'on',
  },
  projects: [
    {
      name: 'chromium',
      use: { 
        ...devices['Desktop Chrome'],
        // Launch options to capture console logs
        launchOptions: {
          args: ['--enable-logging']
        }
      },
    },
  ],
  // Run local dev server before starting tests
  webServer: {
    command: 'bundle exec rails s -p 3000',
    port: 3000,
    reuseExistingServer: !process.env.CI,
  },
});