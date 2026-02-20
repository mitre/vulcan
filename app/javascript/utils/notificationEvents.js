/**
 * Shared notification event bus using native CustomEvents.
 * Works across all 14 separate Vue instances since events are on `document`.
 */

export const EVENTS = {
  LOCKOUT_CHANGED: "vulcan:lockout-changed",
  ACCESS_REQUEST_CHANGED: "vulcan:access-request-changed",
};

/**
 * Dispatch a notification event.
 * @param {string} eventName - One of EVENTS constants
 * @param {Object} detail - Event payload
 */
export function dispatch(eventName, detail) {
  document.dispatchEvent(new CustomEvent(eventName, { detail }));
}

/**
 * Listen for a notification event.
 * @param {string} eventName - One of EVENTS constants
 * @param {Function} handler - Event handler
 * @returns {Function} Cleanup function that removes the listener
 */
export function listen(eventName, handler) {
  document.addEventListener(eventName, handler);
  return () => document.removeEventListener(eventName, handler);
}
