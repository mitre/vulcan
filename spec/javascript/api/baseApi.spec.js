import { describe, it, expect, vi } from "vitest";
import api, { handleSessionExpired } from "@/api/baseApi";

const { kyPut } = vi.hoisted(() => ({ kyPut: vi.fn() }));

vi.mock("ky", () => ({
  default: {
    create: () => ({
      get: vi.fn(),
      post: vi.fn(),
      put: (...args) => kyPut(...args),
      patch: vi.fn(),
      delete: vi.fn(),
    }),
  },
}));

describe("baseApi", () => {
  it("exports an object with get, post, put, patch, delete methods", () => {
    expect(typeof api.get).toBe("function");
    expect(typeof api.post).toBe("function");
    expect(typeof api.put).toBe("function");
    expect(typeof api.patch).toBe("function");
    expect(typeof api.delete).toBe("function");
  });

  it("does not expose axios-specific properties", () => {
    expect(api.create).toBeUndefined();
    expect(api.interceptors).toBeUndefined();
  });

  it("exposes setHeader for controlled header access", () => {
    expect(typeof api.setHeader).toBe("function");
  });

  it("exposes defaults.headers for legacy FormMixin compatibility", () => {
    expect(api.defaults).toBeDefined();
    expect(api.defaults.headers).toBeDefined();
    expect(api.defaults.headers.common).toBeDefined();
  });

  it("uses ky as the underlying HTTP client", () => {
    expect(api._client).toBe("ky");
  });

  // ── Success-body parsing ───────────────────────────────────────────
  // REQUIREMENT: +json structured-syntax suffixes (application/problem+json,
  // application/vnd.api+json — RFC 6839) parse as JSON, not text, matching
  // ky's own error-body detection.
  describe("parseBody content-type detection", () => {
    it("parses +json suffixed media types as JSON", async () => {
      kyPut.mockResolvedValueOnce({
        status: 200,
        headers: new Headers({ "content-type": "application/problem+json; charset=utf-8" }),
        text: () => Promise.resolve('{"type":"/docs/api/errors#not_found","title":"Not found"}'),
      });
      const { data, status } = await api.put("/anything", {});
      expect(status).toBe(200);
      expect(data).toEqual({ type: "/docs/api/errors#not_found", title: "Not found" });
    });

    it("still parses plain application/json as JSON", async () => {
      kyPut.mockResolvedValueOnce({
        status: 200,
        headers: new Headers({ "content-type": "application/json; charset=utf-8" }),
        text: () => Promise.resolve('{"ok":true}'),
      });
      const { data } = await api.put("/anything", {});
      expect(data).toEqual({ ok: true });
    });

    it("falls back to text for non-JSON media types", async () => {
      kyPut.mockResolvedValueOnce({
        status: 200,
        headers: new Headers({ "content-type": "text/csv" }),
        json: () => Promise.reject(new Error("not json")),
        text: () => Promise.resolve("a,b,c"),
      });
      const { data } = await api.put("/anything", {});
      expect(data).toEqual("a,b,c");
    });
  });

  // ── Empty-body success responses ───────────────────────────────────
  // REQUIREMENT: a bodyless success — HTTP 204/205, or a Rails `head :ok`
  // (a 200 with no content) — must RESOLVE to { data: null }, never reject.
  // Calling response.json() on an empty body throws SyntaxError, which turned
  // a successful bodyless action (consent acknowledge, template delete) into a
  // rejected request: the consent modal stayed open even though the server had
  // recorded the acknowledgment.
  describe("empty-body success responses", () => {
    const empty = () => Promise.resolve("");
    const jsonOnEmpty = () => Promise.reject(new SyntaxError("Unexpected end of JSON input"));

    it("resolves a 204 No Content to null data", async () => {
      kyPut.mockResolvedValueOnce({
        status: 204,
        headers: new Headers(),
        json: jsonOnEmpty,
        text: empty,
      });
      const { data, status } = await api.put("/anything", {});
      expect(status).toBe(204);
      expect(data).toBeNull();
    });

    it("resolves a bodyless 200 (Rails head :ok) to null even when typed application/json", async () => {
      kyPut.mockResolvedValueOnce({
        status: 200,
        headers: new Headers({ "content-type": "application/json; charset=utf-8" }),
        json: jsonOnEmpty,
        text: empty,
      });
      const { data, status } = await api.put("/anything", {});
      expect(status).toBe(200);
      expect(data).toBeNull();
    });
  });

  // ── HTTP-error normalization ───────────────────────────────────────
  // REQUIREMENT: on 4xx/5xx the thrown error must carry the SERVER's parsed
  // body at error.response.data so alertOrNotifyResponse can render the
  // canonical {toast} the controller sent (e.g. validation messages) —
  // not the generic "Request failed" fallback.
  //
  // ky v2 pre-parses the error body into error.data and CONSUMES the
  // Response body in the process — error.response.json() rejects with
  // "Body has already been read". The fake below models that reality;
  // re-parsing the response is therefore a bug, not an option.
  describe("normalized HTTP errors", () => {
    const consumedBody = () => Promise.reject(new TypeError("Body has already been read"));

    function kyHttpError({ data, status = 422 }) {
      return Object.assign(
        new Error(`Request failed with status code ${status} Unprocessable Content: PUT /users`),
        {
          name: "HTTPError",
          data,
          response: {
            status,
            headers: new Headers({ "content-type": "application/json; charset=utf-8" }),
            json: consumedBody,
            text: consumedBody,
          },
        },
      );
    }

    it("exposes ky's pre-parsed error.data as error.response.data", async () => {
      kyPut.mockRejectedValueOnce(
        kyHttpError({
          data: {
            toast: {
              title: "Could not update profile.",
              message: ["Current password can't be blank"],
              variant: "danger",
            },
          },
        }),
      );
      await expect(api.put("/users", { user: { name: "x" } })).rejects.toMatchObject({
        response: {
          status: 422,
          data: {
            toast: {
              title: "Could not update profile.",
              message: ["Current password can't be blank"],
              variant: "danger",
            },
          },
        },
      });
    });

    it("normalizes an empty error body to null data", async () => {
      kyPut.mockRejectedValueOnce(kyHttpError({ data: undefined, status: 500 }));
      await expect(api.put("/users", { user: { name: "x" } })).rejects.toMatchObject({
        response: { status: 500, data: null },
      });
    });

    it("rethrows non-HTTP errors untouched", async () => {
      const networkError = Object.assign(new Error("fetch failed"), { name: "NetworkError" });
      kyPut.mockRejectedValueOnce(networkError);
      await expect(api.put("/users", { user: { name: "x" } })).rejects.toBe(networkError);
    });
  });

  // ── expired-session 401 handling ───────────────────────────────────
  // REQUIREMENT: a 401 on ajax means the session died (timeout, or the
  // user signed in elsewhere via session_limitable). The page must
  // RELOAD — a navigational request lets Devise's FailureApp set the
  // cause-specific flash and store user_return_to — rather than jumping
  // straight to the sign-in path (which loses both).
  describe("handleSessionExpired", () => {
    const fakeLoc = (pathname = "/projects/1") => ({ pathname, reload: vi.fn() });

    it("reloads the page on 401 so Devise sets flash + return-to", () => {
      const loc = fakeLoc();
      handleSessionExpired({ response: { status: 401 } }, loc);
      expect(loc.reload).toHaveBeenCalledTimes(1);
    });

    it("does nothing on non-401 responses", () => {
      const loc = fakeLoc();
      handleSessionExpired({ response: { status: 200 } }, loc);
      handleSessionExpired({ response: { status: 403 } }, loc);
      expect(loc.reload).not.toHaveBeenCalled();
    });

    it("does nothing when already on the sign-in page (no reload loop)", () => {
      const loc = fakeLoc("/users/sign_in");
      handleSessionExpired({ response: { status: 401 } }, loc);
      expect(loc.reload).not.toHaveBeenCalled();
    });
  });
});
