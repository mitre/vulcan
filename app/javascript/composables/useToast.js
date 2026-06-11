import _ from "lodash";

/**
 * useToast — app-wide toast notifications for Vue 2.7 (replaces the legacy
 * alert mixin)
 *
 * Architecture: each esbuild pack is an isolated iife bundle (no code
 * splitting), so module-level state is NEVER shared between the pack that
 * produces a toast (projects, rules, users, ...) and the toaster pack that
 * renders it. The producer→renderer transport is therefore a DOM
 * CustomEvent — the codebase's established cross-pack bridge (see
 * "vulcan:lockout-changed" in EditUserModal → Navbar).
 *
 * - Producers call useToast() anywhere (setup or options API) and dispatch
 *   plain-data payloads. No Vue instance, no $bvToast, no getCurrentInstance.
 * - Toaster.vue (toaster pack, mounted on every page) is the ONE component
 *   that listens for TOAST_EVENT and calls $bvToast.toast, building any
 *   VNode bodies (paragraph arrays, permission-denied admin lists) with a
 *   real render context.
 *
 * Payload contract ({@link TOAST_EVENT} detail):
 *   { title, variant, message, admins?, autoHideDelay? }
 *   - message: string or array of strings (arrays render as paragraphs)
 *   - admins: [{name, email}] — present only on permission-denied toasts
 */

export const TOAST_EVENT = "vulcan:toast";

function dispatchToast(detail) {
  document.dispatchEvent(new CustomEvent(TOAST_EVENT, { detail }));
}

/**
 * Show a toast.
 *
 * @param {string|string[]} message - Body text; arrays render as paragraphs.
 * @param {Object} [options]
 * @param {string} [options.title="Success"]
 * @param {string} [options.variant="success"]
 * @param {number} [options.autoHideDelay] - Milliseconds before auto-hide.
 */
function showToast(message, { title = "Success", variant = "success", ...extra } = {}) {
  dispatchToast({ title, variant, message, ...extra });
}

function showSuccess(message, title = "Success") {
  showToast(message, { title, variant: "success" });
}

function showError(message, title = "Error") {
  showToast(message, { title, variant: "danger" });
}

function showWarning(message, title = "Warning") {
  showToast(message, { title, variant: "warning" });
}

/**
 * Take in a `response` directly from an AJAX call and see if it contains
 * data that we can turn into a toast. Behavior-identical port of the legacy
 * alert mixin's alertOrNotifyResponse.
 *
 * Looks for a canonical {title, message, variant} toast object at
 * - response.data.toast (success responses)
 * - response.response.data.toast (HTTP-error responses — baseApi reshapes
 *   ky HTTPErrors to this legacy axios shape)
 *
 * Structured permission-denied responses (403 + error === 'permission_denied')
 * get a rich danger toast carrying the project admin contacts so the user
 * knows who to ask for access.
 *
 * If a backend ever returns a non-object toast we fall through to the
 * generic error branch so the regression is visible, not silent.
 *
 * @param {Object} response - Resolved response or normalized request error.
 */
function alertOrNotifyResponse(response) {
  const errorData = response?.response?.data;
  if (response?.response?.status === 403 && errorData?.error === "permission_denied") {
    dispatchToast({
      title: "Permission denied",
      variant: "danger",
      message: errorData.message,
      admins: Array.isArray(errorData.admins) ? errorData.admins : [],
      autoHideDelay: 8000,
    });
    return;
  }

  const toast = response?.data?.toast || errorData?.toast || null;
  if (_.isPlainObject(toast)) {
    showToast(toast.message, {
      title: toast.title || "Success",
      variant: toast.variant || "success",
    });
    return;
  }

  // At this point it is likely an error has occurred.
  if (response.message) {
    showError(response.message);
  }
}

/**
 * @returns {Object} Toast methods — safe to destructure anywhere; no
 *   component instance required.
 */
export function useToast() {
  return {
    showToast,
    showSuccess,
    showError,
    showWarning,
    alertOrNotifyResponse,
  };
}
