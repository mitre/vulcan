// Debug utilities for Vulcan Vue app
// This file contains debugging tools that can be imported when needed

// Setup enhanced console logging
const originalConsoleLog = console.log;
const originalConsoleWarn = console.warn;
const originalConsoleError = console.error;

// Store logs in memory
window.consoleLogs = [];
window.consoleErrors = [];
window.consoleWarnings = [];

// Maximum number of logs to keep
const MAX_LOGS = 100;

// Create a log capture function
const captureLog = (type, args) => {
  const timestamp = new Date().toISOString();
  const logEntry = {
    type,
    timestamp,
    message: Array.from(args).map(arg => {
      if (typeof arg === 'object') {
        try {
          return JSON.stringify(arg);
        } catch (e) {
          return String(arg);
        }
      }
      return String(arg);
    }).join(' ')
  };
  
  // Store in appropriate array
  if (type === 'error') {
    window.consoleErrors.push(logEntry);
    if (window.consoleErrors.length > MAX_LOGS) {
      window.consoleErrors.shift();
    }
  } else if (type === 'warn') {
    window.consoleWarnings.push(logEntry);
    if (window.consoleWarnings.length > MAX_LOGS) {
      window.consoleWarnings.shift();
    }
  } else {
    window.consoleLogs.push(logEntry);
    if (window.consoleLogs.length > MAX_LOGS) {
      window.consoleLogs.shift();
    }
  }
  
  // Return log entry for later use
  return logEntry;
};

// Override console methods
console.log = function() {
  captureLog('log', arguments);
  originalConsoleLog.apply(console, arguments);
};

console.warn = function() {
  captureLog('warn', arguments);
  originalConsoleWarn.apply(console, arguments);
};

console.error = function() {
  captureLog('error', arguments);
  originalConsoleError.apply(console, arguments);
};

// Add helper to dump logs to an HTML element
window.dumpLogs = function(elementId = 'console-log-dump') {
  let el = document.getElementById(elementId);
  if (!el) {
    el = document.createElement('div');
    el.id = elementId;
    el.style.cssText = 'position: fixed; top: 0; right: 0; width: 400px; height: 300px; overflow: auto; background: rgba(0,0,0,0.8); color: white; z-index: 10000; padding: 10px; font-family: monospace; font-size: 12px;';
    document.body.appendChild(el);
  }
  
  el.innerHTML = '<h4>Console Errors</h4>';
  window.consoleErrors.forEach(entry => {
    el.innerHTML += `<div style="color: red">[${entry.timestamp.split('T')[1].split('.')[0]}] ${entry.message}</div>`;
  });
  
  el.innerHTML += '<h4>Console Warnings</h4>';
  window.consoleWarnings.forEach(entry => {
    el.innerHTML += `<div style="color: orange">[${entry.timestamp.split('T')[1].split('.')[0]}] ${entry.message}</div>`;
  });
  
  el.innerHTML += '<h4>Console Logs</h4>';
  window.consoleLogs.slice(-20).forEach(entry => {
    el.innerHTML += `<div>[${entry.timestamp.split('T')[1].split('.')[0]}] ${entry.message}</div>`;
  });
  
  return {
    errors: window.consoleErrors,
    warnings: window.consoleWarnings,
    logs: window.consoleLogs
  };
};

// Add keyboard shortcut to show logs: Shift+Ctrl+L
document.addEventListener('keydown', function(e) {
  if (e.shiftKey && e.ctrlKey && e.key === 'L') {
    window.dumpLogs();
    e.preventDefault();
  }
});

// Add a method to get logs as JSON string for easy copying
window.getVulcanConsoleLogs = function() {
  return JSON.stringify({
    errors: window.consoleErrors,
    warnings: window.consoleWarnings,
    logs: window.consoleLogs.slice(-30) // Limit to last 30 logs
  }, null, 2);
};

// Export debugging utils
export const setupDebugging = () => {
  console.log('Debug utilities initialized');
};

export default { setupDebugging };