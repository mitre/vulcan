import { describe, it, expect, vi, afterEach } from "vitest";
import { EVENTS, dispatch, listen } from "@/utils/notificationEvents";

/**
 * Notification Events Utility Requirements:
 *
 * 1. EVENTS constants provide named event strings
 * 2. dispatch() fires a CustomEvent on document with the given detail
 * 3. listen() registers a handler and returns a cleanup function
 * 4. Cleanup function removes the listener so it no longer fires
 */
describe("notificationEvents", () => {
  const handlers = [];

  afterEach(() => {
    handlers.forEach((cleanup) => cleanup());
    handlers.length = 0;
  });

  describe("EVENTS", () => {
    it("exposes LOCKOUT_CHANGED constant", () => {
      expect(EVENTS.LOCKOUT_CHANGED).toBe("vulcan:lockout-changed");
    });

    it("exposes ACCESS_REQUEST_CHANGED constant", () => {
      expect(EVENTS.ACCESS_REQUEST_CHANGED).toBe("vulcan:access-request-changed");
    });
  });

  describe("dispatch", () => {
    it("fires a CustomEvent with the correct detail", () => {
      const handler = vi.fn();
      const cleanup = listen(EVENTS.LOCKOUT_CHANGED, handler);
      handlers.push(cleanup);

      const detail = { action: "locked", user: { id: 1 } };
      dispatch(EVENTS.LOCKOUT_CHANGED, detail);

      expect(handler).toHaveBeenCalledTimes(1);
      expect(handler.mock.calls[0][0].detail).toEqual(detail);
    });
  });

  describe("listen", () => {
    it("registers a handler that receives events", () => {
      const handler = vi.fn();
      const cleanup = listen(EVENTS.ACCESS_REQUEST_CHANGED, handler);
      handlers.push(cleanup);

      dispatch(EVENTS.ACCESS_REQUEST_CHANGED, { action: "resolved", id: 5 });

      expect(handler).toHaveBeenCalledTimes(1);
    });

    it("returns a cleanup function that removes the listener", () => {
      const handler = vi.fn();
      const cleanup = listen(EVENTS.LOCKOUT_CHANGED, handler);

      dispatch(EVENTS.LOCKOUT_CHANGED, { action: "locked" });
      expect(handler).toHaveBeenCalledTimes(1);

      cleanup();

      dispatch(EVENTS.LOCKOUT_CHANGED, { action: "unlocked" });
      expect(handler).toHaveBeenCalledTimes(1); // Still 1, not called again
    });
  });
});
