// @ts-check
const { test, expect } = require('@playwright/test');
const fs = require('fs');

// ===== ASSET VALIDATION TEST HELPER =====
class AssetValidator {
  constructor(page) {
    this.page = page;
    this.assetRequests = [];
    this.jsModules = [];
    this.cssFiles = [];
    this.consoleMessages = [];
    this.consoleErrors = [];
    
    // Set up listeners for tracking assets
    this.setupListeners();
  }
  
  setupListeners() {
    // Track all network requests
    this.page.on('request', request => {
      if (request.resourceType() === 'script' || request.resourceType() === 'stylesheet') {
        this.assetRequests.push({
          url: request.url(),
          type: request.resourceType(),
          method: request.method()
        });
        
        // Track JS modules separately
        if (request.resourceType() === 'script' && request.url().includes('/assets/')) {
          this.jsModules.push(request.url());
        }
        
        // Track CSS files separately
        if (request.resourceType() === 'stylesheet' && request.url().includes('/assets/')) {
          this.cssFiles.push(request.url());
        }
      }
    });
    
    // Track console logs
    this.page.on('console', msg => {
      this.consoleMessages.push({
        type: msg.type(),
        text: msg.text()
      });
      
      // Track errors separately
      if (msg.type() === 'error') {
        this.consoleErrors.push(msg.text());
      }
    });
    
    // Track page errors
    this.page.on('pageerror', error => {
      this.consoleErrors.push(error.message);
    });
  }
  
  // Generate a report of asset loading
  generateReport() {
    return {
      totalAssetRequests: this.assetRequests.length,
      jsModules: this.jsModules,
      cssFiles: this.cssFiles,
      consoleErrors: this.consoleErrors,
      consoleMessages: this.consoleMessages
    };
  }
  
  // Validate asset loading
  async validateAssetLoading() {
    // Check if we loaded JS modules
    expect(this.jsModules.length).toBeGreaterThan(0);
    
    // Check if we loaded CSS files
    expect(this.cssFiles.length).toBeGreaterThan(0);
    
    // Check for loading errors
    const assetErrors = this.consoleErrors.filter(
      error => error.includes('Failed to load resource') || 
               error.includes('Error loading') ||
               error.includes('module error')
    );
    
    // Log any asset errors for debugging
    if (assetErrors.length > 0) {
      console.error('Asset loading errors detected:');
      assetErrors.forEach(error => console.error(`- ${error}`));
    }
    
    // Check for proper module type
    const scriptTags = await this.page.$$eval('script[type="module"]', scripts => scripts.length);
    expect(scriptTags).toBeGreaterThan(0);
    
    return assetErrors.length === 0;
  }
  
  // Validate Vue component mounting
  async validateVueComponentMounting(componentSelector) {
    // Check for Vue warnings
    const vueErrors = this.consoleErrors.filter(
      error => error.includes('Vue') || error.includes('component')
    );
    
    // Log any Vue errors for debugging
    if (vueErrors.length > 0) {
      console.error('Vue errors detected:');
      vueErrors.forEach(error => console.error(`- ${error}`));
    }
    
    // Check if the component is rendered
    if (componentSelector) {
      const isRendered = await this.page.$(componentSelector) !== null;
      expect(isRendered).toBeTruthy();
    }
    
    return vueErrors.length === 0;
  }
}

// ===== LOGIN HELPER =====
async function login(page, email = 'admin@example.com', password = '1234567ab!') {
  await page.goto('/users/sign_in');
  await page.fill('#user_email', email);
  await page.fill('#user_password', password);
  
  // Submit login form
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle' }),
    page.click('input[type="submit"]')
  ]);
  
  // Save screenshot for verification
  await page.screenshot({ path: './tests/e2e/login-result.png', fullPage: true });
  
  // Verify login was successful
  const userInfo = await page.locator('.navbar').textContent();
  expect(userInfo).toBeTruthy();
}

// ===== TEST SUITE =====
test.describe('jsbundling-rails Migration Validation', () => {
  
  // Test login page assets
  test('Login page loads assets correctly', async ({ page }) => {
    const validator = new AssetValidator(page);
    
    // Navigate to login page
    await page.goto('/users/sign_in');
    
    // Wait for page to load completely
    await page.waitForLoadState('networkidle');
    
    // Take screenshot for verification
    await page.screenshot({ path: './tests/e2e/login-page.png', fullPage: true });
    
    // Check for application.js module
    const hasApplicationJS = validator.jsModules.some(url => url.includes('application'));
    expect(hasApplicationJS).toBeTruthy();
    
    // Check for application.css
    const hasApplicationCSS = validator.cssFiles.some(url => url.includes('application'));
    expect(hasApplicationCSS).toBeTruthy();
    
    // Validate all assets loaded correctly
    const assetsValid = await validator.validateAssetLoading();
    expect(assetsValid).toBeTruthy();
    
    // Check if Vue is loaded and initialized
    const vueInitialized = validator.consoleMessages.some(
      msg => msg.text.includes('Vue version:')
    );
    expect(vueInitialized).toBeTruthy();
    
    // Save full report for debugging
    fs.writeFileSync(
      './tests/e2e/login-assets-report.json', 
      JSON.stringify(validator.generateReport(), null, 2)
    );
  });
  
  // Test navbar component
  test('Navbar component renders correctly', async ({ page }) => {
    const validator = new AssetValidator(page);
    
    // Login first
    await login(page);
    
    // Verify navbar JS is loaded
    const hasNavbarJS = validator.jsModules.some(url => url.includes('navbar'));
    expect(hasNavbarJS).toBeTruthy();
    
    // Check if navbar Vue component is rendered
    await page.waitForSelector('#navbar', { state: 'visible' });
    const navbarRendered = await page.$('#navbar nav');
    expect(navbarRendered).not.toBeNull();
    
    // Check for Bootstrap Vue components
    const dropdownsRendered = await page.$$('.dropdown');
    expect(dropdownsRendered.length).toBeGreaterThan(0);
    
    // Check for icons rendering
    const iconsRendered = await page.$$('svg.bi');
    expect(iconsRendered.length).toBeGreaterThan(0);
    
    // Take screenshot of navbar for visual verification
    const navbarElement = await page.$('#navbar');
    if (navbarElement) {
      await navbarElement.screenshot({ path: './tests/e2e/navbar-component.png' });
    }
    
    // Validate Vue component mounted correctly
    const vueValid = await validator.validateVueComponentMounting('#navbar');
    expect(vueValid).toBeTruthy();
  });
  
  // Test projects listing page
  test('Projects page loads and renders components', async ({ page }) => {
    const validator = new AssetValidator(page);
    
    // Login first
    await login(page);
    
    // Navigate to projects page
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle' }),
      page.goto('/projects')
    ]);
    
    // Verify projects JS module is loaded
    const hasProjectsJS = validator.jsModules.some(url => url.includes('projects'));
    expect(hasProjectsJS).toBeTruthy();
    
    // Check if the Vue component is rendered
    await page.waitForSelector('#Projects', { state: 'visible' });
    
    // Check for specific Bootstrap-Vue components (table, buttons)
    const hasBTable = await page.$('.b-table');
    const hasButtons = await page.$$('button.btn');
    
    expect(hasBTable).not.toBeNull();
    expect(hasButtons.length).toBeGreaterThan(0);
    
    // Take screenshot for verification
    await page.screenshot({ path: './tests/e2e/projects-page.png', fullPage: true });
    
    // Validate Vue component mounted correctly
    const vueValid = await validator.validateVueComponentMounting('#Projects');
    expect(vueValid).toBeTruthy();
    
    // Save asset report
    fs.writeFileSync(
      './tests/e2e/projects-assets-report.json', 
      JSON.stringify(validator.generateReport(), null, 2)
    );
  });
  
  // Test security_requirements_guides listing page
  test('SRGs page loads and renders components', async ({ page }) => {
    const validator = new AssetValidator(page);
    
    // Login first
    await login(page);
    
    // Navigate to SRGs page
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle' }),
      page.goto('/srgs')
    ]);
    
    // Verify security_requirements_guides JS module is loaded
    const hasSRGsJS = validator.jsModules.some(url => url.includes('security_requirements_guides'));
    expect(hasSRGsJS).toBeTruthy();
    
    // Check if the Vue component is rendered
    await page.waitForSelector('#SecurityRequirementsGuides', { state: 'visible' });
    
    // Take screenshot for verification
    await page.screenshot({ path: './tests/e2e/srgs-page.png', fullPage: true });
    
    // Validate Vue component mounted correctly
    const vueValid = await validator.validateVueComponentMounting('#SecurityRequirementsGuides');
    expect(vueValid).toBeTruthy();
    
    // Save asset report
    fs.writeFileSync(
      './tests/e2e/srgs-assets-report.json', 
      JSON.stringify(validator.generateReport(), null, 2)
    );
  });
  
  // Test STIGs listing page
  test('STIGs page loads and renders components', async ({ page }) => {
    const validator = new AssetValidator(page);
    
    // Login first
    await login(page);
    
    // Navigate to STIGs page
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle' }),
      page.goto('/stigs')
    ]);
    
    // Verify stigs JS module is loaded
    const hasSTIGsJS = validator.jsModules.some(url => url.includes('stigs'));
    expect(hasSTIGsJS).toBeTruthy();
    
    // Check if the Vue component is rendered
    await page.waitForSelector('#Stigs', { state: 'visible' });
    
    // Take screenshot for verification
    await page.screenshot({ path: './tests/e2e/stigs-page.png', fullPage: true });
    
    // Validate Vue component mounted correctly
    const vueValid = await validator.validateVueComponentMounting('#Stigs');
    expect(vueValid).toBeTruthy();
    
    // Save asset report
    fs.writeFileSync(
      './tests/e2e/stigs-assets-report.json', 
      JSON.stringify(validator.generateReport(), null, 2)
    );
  });
  
  // Test Users page
  test('Users page loads and renders components', async ({ page }) => {
    const validator = new AssetValidator(page);
    
    // Login first
    await login(page);
    
    // Navigate to Users page
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle' }),
      page.goto('/users')
    ]);
    
    // Verify users JS module is loaded
    const hasUsersJS = validator.jsModules.some(url => url.includes('users'));
    expect(hasUsersJS).toBeTruthy();
    
    // Check if the Vue component is rendered
    await page.waitForSelector('#Users', { state: 'visible' });
    
    // Take screenshot for verification
    await page.screenshot({ path: './tests/e2e/users-page.png', fullPage: true });
    
    // Validate Vue component mounted correctly
    const vueValid = await validator.validateVueComponentMounting('#Users');
    expect(vueValid).toBeTruthy();
    
    // Save asset report
    fs.writeFileSync(
      './tests/e2e/users-assets-report.json', 
      JSON.stringify(validator.generateReport(), null, 2)
    );
  });
});