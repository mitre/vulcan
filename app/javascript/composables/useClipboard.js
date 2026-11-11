import { useToast } from "./useToast";

// Copies through a hidden, read-only textarea and execCommand("copy"), the
// fallback for pages without the Clipboard API. Returns whether it copied.
function legacyCopy(text) {
  const textarea = document.createElement("textarea");
  textarea.value = text;
  textarea.setAttribute("readonly", "");
  textarea.style.position = "fixed";
  textarea.style.opacity = "0";
  document.body.appendChild(textarea);
  try {
    textarea.select();
    return document.execCommand("copy") === true;
  } catch {
    return false;
  } finally {
    textarea.remove();
  }
}

/**
 * useClipboard — copy text to the user's clipboard and report whether it
 * actually happened.
 *
 * navigator.clipboard exists only in a secure context, and Vulcan defaults
 * RAILS_FORCE_SSL=false, so an internal HTTP deployment has no clipboard API.
 * writeText can also be refused (no permission, document not focused). In
 * both cases the text is copied with a hidden textarea and
 * execCommand("copy"). If that fails too, the user gets a warning toast
 * telling them to copy by hand.
 *
 * copyText resolves true only after the text was copied, so callers show
 * success feedback only for a copy that happened.
 */
export function useClipboard() {
  const { showWarning } = useToast();

  /**
   * @param {string} text - The text to copy.
   * @param {Object} [options]
   * @param {string} [options.what="it"] - Names the text in the failure
   *   message, e.g. "the token" -> "select and copy the token manually".
   * @returns {Promise<boolean>} Whether the text was copied.
   */
  async function copyText(text, { what = "it" } = {}) {
    if (navigator.clipboard?.writeText) {
      try {
        await navigator.clipboard.writeText(text);
        return true;
      } catch {
        // Refused: fall through to the execCommand copy below.
      }
    }
    if (legacyCopy(text)) return true;
    showWarning(
      [`Could not copy automatically — select and copy ${what} manually.`],
      "Copy failed",
    );
    return false;
  }

  return { copyText };
}
