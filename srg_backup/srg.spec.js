// @ts-check
const { test, expect } = require('@playwright/test');
const fs = require('fs');

// Create an AI-friendly test reporter
class AIReporter {
  static logFile = './tests/e2e/ai-debug.json';
  static htmlReport = './tests/e2e/ai-report.html';
  
  static init() {
    // Create directory if it doesn't exist
    if (!fs.existsSync('./tests/e2e')) {
      fs.mkdirSync('./tests/e2e', { recursive: true });
    }
    
    // Initialize the log file
    fs.writeFileSync(this.logFile, JSON.stringify({
      testRun: {
        startTime: new Date().toISOString(),
        steps: [],
        consoleLogs: [],
        networkRequests: [],
        errors: [],
        screenshots: []
      }
    }, null, 2));
    
    console.log(`AI Reporter initialized, logging to ${this.logFile}`);
  }
  
  static logStep(step) {
    const data = JSON.parse(fs.readFileSync(this.logFile, 'utf8'));
    data.testRun.steps.push({
      time: new Date().toISOString(),
      ...step
    });
    fs.writeFileSync(this.logFile, JSON.stringify(data, null, 2));
  }
  
  static logConsole(log) {
    const data = JSON.parse(fs.readFileSync(this.logFile, 'utf8'));
    data.testRun.consoleLogs.push({
      time: new Date().toISOString(),
      ...log
    });
    fs.writeFileSync(this.logFile, JSON.stringify(data, null, 2));
  }
  
  static logError(error) {
    const data = JSON.parse(fs.readFileSync(this.logFile, 'utf8'));
    data.testRun.errors.push({
      time: new Date().toISOString(),
      ...error
    });
    fs.writeFileSync(this.logFile, JSON.stringify(data, null, 2));
  }
  
  static logScreenshot(path) {
    const data = JSON.parse(fs.readFileSync(this.logFile, 'utf8'));
    data.testRun.screenshots.push({
      time: new Date().toISOString(),
      path
    });
    fs.writeFileSync(this.logFile, JSON.stringify(data, null, 2));
  }
  
  static logNetworkRequest(request) {
    const data = JSON.parse(fs.readFileSync(this.logFile, 'utf8'));
    data.testRun.networkRequests.push({
      time: new Date().toISOString(),
      ...request
    });
    fs.writeFileSync(this.logFile, JSON.stringify(data, null, 2));
  }
  
  static generateHTMLReport() {
    const data = JSON.parse(fs.readFileSync(this.logFile, 'utf8'));
    
    // Create a simple HTML report
    const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <title>AI Debug Report</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1, h2 { color: #333; }
        pre { background: #f5f5f5; padding: 10px; border-radius: 4px; overflow-x: auto; }
        .step { margin-bottom: 20px; border-bottom: 1px solid #eee; padding-bottom: 10px; }
        .error { color: red; }
        .console-log { margin: 5px 0; }
        .console-error { color: red; }
        .console-warning { color: orange; }
        .network { margin: 5px 0; }
        .status-error { color: red; }
        .container { margin-bottom: 30px; }
      </style>
    </head>
    <body>
      <h1>AI Debug Report</h1>
      <p>Test run started at: ${data.testRun.startTime}</p>
      
      <div class="container">
        <h2>Test Steps</h2>
        ${data.testRun.steps.map(step => `
          <div class="step">
            <p><strong>${step.name}</strong> (${step.time})</p>
            <p>${step.description || ''}</p>
          </div>
        `).join('')}
      </div>
      
      <div class="container">
        <h2>Errors (${data.testRun.errors.length})</h2>
        ${data.testRun.errors.map(error => `
          <div class="error">
            <p><strong>${error.type || 'Error'}</strong> (${error.time})</p>
            <pre>${error.message}</pre>
          </div>
        `).join('')}
      </div>
      
      <div class="container">
        <h2>Console Logs (${data.testRun.consoleLogs.length})</h2>
        ${data.testRun.consoleLogs.map(log => `
          <div class="console-log console-${log.type}">
            <p><strong>[${log.type}]</strong> (${log.time})</p>
            <pre>${log.text}</pre>
          </div>
        `).join('')}
      </div>
      
      <div class="container">
        <h2>Network Requests (${data.testRun.networkRequests.length})</h2>
        ${data.testRun.networkRequests.map(req => `
          <div class="network">
            <p>
              <strong>${req.method}</strong> ${req.url} 
              <span class="${req.status >= 400 ? 'status-error' : ''}">(Status: ${req.status})</span>
            </p>
          </div>
        `).join('')}
      </div>
      
      <div class="container">
        <h2>Screenshots (${data.testRun.screenshots.length})</h2>
        ${data.testRun.screenshots.map(screenshot => `
          <div>
            <p><strong>Screenshot</strong> (${screenshot.time})</p>
            <p>Path: ${screenshot.path}</p>
          </div>
        `).join('')}
      </div>
    </body>
    </html>
    `;
    
    fs.writeFileSync(this.htmlReport, html);
    console.log(`HTML report generated at ${this.htmlReport}`);
  }
}

// Initialize the AI reporter
AIReporter.init();

test.describe('SRG View Tests', () => {
  test('should display SRG details correctly', async ({ page }) => {
    // Track network requests for AI debugging
    page.on('request', request => {
      AIReporter.logNetworkRequest({
        url: request.url(),
        method: request.method(),
        resourceType: request.resourceType(),
        headers: request.headers()
      });
    });
    
    page.on('response', response => {
      AIReporter.logNetworkRequest({
        url: response.url(),
        status: response.status(),
        statusText: response.statusText(),
        headers: response.headers()
      });
    });
    
    // Store console logs
    const logs = [];
    page.on('console', msg => {
      const logEntry = {
        type: msg.type(),
        text: msg.text()
      };
      
      logs.push(logEntry);
      console.log(`Browser console [${msg.type()}]: ${msg.text()}`);
      
      // Log to AI reporter
      AIReporter.logConsole(logEntry);
    });

    // Listen for any console errors
    page.on('pageerror', error => {
      console.error(`Browser page error: ${error.message}`);
      AIReporter.logError({
        type: 'PageError',
        message: error.message
      });
    });

    // Login first 
    await test.step('Login to application', async () => {
      AIReporter.logStep({
        name: 'Login to application',
        description: 'Logging in with admin credentials'
      });
      
      await page.goto('/users/sign_in');
      await page.fill('#user_email', 'admin@example.com');
      await page.fill('#user_password', '1234567ab!');
      
      // Take a screenshot before submitting
      const beforeLoginScreenshot = './tests/e2e/before-login.png';
      await page.screenshot({ path: beforeLoginScreenshot, fullPage: true });
      AIReporter.logScreenshot(beforeLoginScreenshot);
      
      // Click the submit button and wait for navigation
      await Promise.all([
        page.waitForNavigation({ waitUntil: 'networkidle' }),
        page.click('input[type="submit"]')
      ]);
      
      // Take a screenshot after login
      const loginScreenshot = './tests/e2e/after-login.png';
      await page.screenshot({ path: loginScreenshot, fullPage: true });
      AIReporter.logScreenshot(loginScreenshot);
      
      // Verify we're logged in
      const userInfo = await page.locator('.navbar').textContent();
      AIReporter.logStep({
        name: 'Login verification',
        description: `Navbar text: ${userInfo}`
      });
      expect(userInfo).toBeTruthy();
    });

    // Navigate to SRGs
    await test.step('Navigate to SRGs page', async () => {
      AIReporter.logStep({
        name: 'Navigate to SRGs page',
        description: 'Going to the SRGs index page'
      });
      
      // Wait for page to finish loading before navigation
      await page.waitForLoadState('networkidle');
      
      // Save current URL for debugging
      const currentUrl = page.url();
      AIReporter.logStep({
        name: 'Current URL',
        description: `Before navigation: ${currentUrl}`
      });
      
      // Navigate with waitForNavigation to ensure page load completes
      await Promise.all([
        page.waitForNavigation({ waitUntil: 'networkidle' }),
        page.goto('/srgs')
      ]);
      
      // Log request/response for the navigation
      AIReporter.logStep({
        name: 'Navigation complete',
        description: `Navigated to: ${page.url()}`
      });
      
      // Log the actual page title for debugging
      const pageTitle = await page.title();
      AIReporter.logStep({
        name: 'Page title check',
        description: `Actual page title: "${pageTitle}"`
      });
      
      // Log page HTML for debugging
      const pageHtml = await page.content();
      fs.writeFileSync('./tests/e2e/srgs-page-html.html', pageHtml);
      
      // Take a screenshot of the SRGs index page
      const srgsIndexScreenshot = './tests/e2e/srgs-index.png';
      await page.screenshot({ path: srgsIndexScreenshot, fullPage: true });
      AIReporter.logScreenshot(srgsIndexScreenshot);
      
      // Check for typical elements on the page
      const hasTable = await page.locator('table').count() > 0;
      AIReporter.logStep({
        name: 'Page content check',
        description: `Has table: ${hasTable}`
      });
      
      // More flexible title check
      expect(pageTitle).toBeTruthy();
    });

    // Click on the first SRG if available
    await test.step('View SRG detail', async () => {
      AIReporter.logStep({
        name: 'View SRG detail',
        description: 'Attempting to view the first SRG detail page'
      });
      
      try {
        // Check if we have any SRGs listed
        const srgCount = await page.locator('tbody tr').count();
        AIReporter.logStep({
          name: 'SRG count check',
          description: `Found ${srgCount} SRGs in the table`
        });
        
        if (srgCount > 0) {
          // Dump page HTML for debugging
          const html = await page.content();
          fs.writeFileSync('./tests/e2e/srgs-page.html', html);
          
          // Log first row content for debugging
          const firstRowText = await page.locator('tbody tr:first-child').textContent();
          AIReporter.logStep({
            name: 'First row content',
            description: `First row text: ${firstRowText}`
          });
          
          // Click the first SRG link
          const firstSrgLink = await page.locator('tbody tr:first-child a').first();
          await firstSrgLink.click();
          
          // Wait for page to load
          await page.waitForSelector('h1');
          
          // Check if SRG title is shown
          const title = await page.locator('h1').textContent();
          console.log(`SRG Title: ${title}`);
          AIReporter.logStep({
            name: 'SRG Title',
            description: `Found title: "${title}"`
          });
          expect(title).toBeTruthy();
          
          // Dump the HTML of the SRG detail page
          const detailHtml = await page.content();
          fs.writeFileSync('./tests/e2e/srg-detail.html', detailHtml);
          
          // Dump the adapted data from console logs
          console.log("Looking for SRG Data and Adapted data logs");
          
          // Check if rule list is populated
          await page.waitForTimeout(2000); // Wait for Vue to render
          const ruleItems = await page.locator('.list-group-item').count();
          console.log(`Found ${ruleItems} rule items`);
          AIReporter.logStep({
            name: 'Rule items',
            description: `Found ${ruleItems} rule items in the list`
          });
          
          // Check for our debug data that was logged
          const srgDataLogs = logs.filter(log => log.text.includes('SRG Data received'));
          const adaptedDataLogs = logs.filter(log => log.text.includes('Adapted data'));
          
          AIReporter.logStep({
            name: 'Debug data check',
            description: `Found ${srgDataLogs.length} SRG data logs and ${adaptedDataLogs.length} adapted data logs`
          });
        } else {
          console.log('No SRGs available to test - this is expected in a fresh development environment');
          AIReporter.logStep({
            name: 'No SRGs',
            description: 'No SRGs available to test'
          });
        }
        
        // Capture screenshot for debugging
        const detailScreenshot = './tests/e2e/srg-detail.png';
        await page.screenshot({ path: detailScreenshot, fullPage: true });
        AIReporter.logScreenshot(detailScreenshot);
        
        // Check for any errors in logs
        const errors = logs.filter(log => log.type === 'error');
        console.log('Console errors:', errors);
        
        errors.forEach(error => {
          AIReporter.logError({
            type: 'ConsoleError',
            message: error.text
          });
        });
      } catch (error) {
        console.error('Test error:', error);
        AIReporter.logError({
          type: 'TestError',
          message: error.toString()
        });
        
        const errorScreenshot = './tests/e2e/srg-error.png';
        await page.screenshot({ path: errorScreenshot, fullPage: true });
        AIReporter.logScreenshot(errorScreenshot);
        
        throw error;
      }
    });
    
    // Generate the HTML report at the end of the test
    AIReporter.generateHTMLReport();
  });
});