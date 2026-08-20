import { describe, it, expect, afterEach } from "vitest";
import { useAuthToken } from "../../../app/javascript/composables/useAuthToken";

describe("useAuthToken", () => {
  it("returns the CSRF token from the meta tag", () => {
    const { authenticityToken } = useAuthToken();
    expect(authenticityToken).toBe("test-csrf-token");
  });

  it("returns the exact content attribute value", () => {
    const meta = document.querySelector("meta[name='csrf-token']");
    meta.setAttribute("content", "changed-token-xyz789");

    const { authenticityToken } = useAuthToken();
    expect(authenticityToken).toBe("changed-token-xyz789");

    meta.setAttribute("content", "test-csrf-token");
  });

  it("returns null when meta tag is missing", () => {
    const meta = document.querySelector("meta[name='csrf-token']");
    meta.parentNode.removeChild(meta);

    const { authenticityToken } = useAuthToken();
    expect(authenticityToken).toBeNull();

    const restored = document.createElement("meta");
    restored.setAttribute("name", "csrf-token");
    restored.setAttribute("content", "test-csrf-token");
    document.head.appendChild(restored);
  });
});
