import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

describe("api_docs.js — Scalar theme integration", () => {
  let createApiReferenceMock;

  beforeEach(() => {
    document.getElementById("scalar-docs")?.remove();
    const div = document.createElement("div");
    div.id = "scalar-docs";
    document.body.appendChild(div);

    createApiReferenceMock = vi.fn(() => ({}));
    globalThis.Scalar = { createApiReference: createApiReferenceMock };

    // Clean body classes
    document.body.classList.remove("dark-mode", "light-mode");
  });

  afterEach(() => {
    delete globalThis.Scalar;
    document.getElementById("scalar-docs")?.remove();
    document.documentElement.removeAttribute("data-bs-theme");
    document.body.classList.remove("dark-mode", "light-mode");
    vi.restoreAllMocks();
    vi.resetModules();
  });

  async function loadApiDocs() {
    vi.resetModules();
    createApiReferenceMock.mockClear();
    const handler = new Promise((resolve) => {
      const origAdd = document.addEventListener.bind(document);
      const spy = vi.spyOn(document, "addEventListener").mockImplementation((event, fn, opts) => {
        origAdd(event, fn, opts);
        if (event === "DOMContentLoaded") {
          resolve(fn);
        }
      });
      import("@/packs/api_docs.js").then(() => spy.mockRestore());
    });
    const domContentLoadedFn = await handler;
    domContentLoadedFn();
  }

  it("reads initial dark mode from [data-bs-theme] attribute", async () => {
    document.documentElement.setAttribute("data-bs-theme", "dark");
    await loadApiDocs();

    expect(createApiReferenceMock).toHaveBeenCalledOnce();
    const config = createApiReferenceMock.mock.calls[0][1];
    expect(config.darkMode).toBe(true);
  });

  it("sets light mode when [data-bs-theme] is not dark", async () => {
    document.documentElement.removeAttribute("data-bs-theme");
    await loadApiDocs();

    expect(createApiReferenceMock).toHaveBeenCalledOnce();
    const config = createApiReferenceMock.mock.calls[0][1];
    expect(config.darkMode).toBe(false);
  });

  it("sets body class to dark-mode when [data-bs-theme] is dark", async () => {
    document.documentElement.setAttribute("data-bs-theme", "dark");
    await loadApiDocs();

    expect(document.body.classList.contains("dark-mode")).toBe(true);
    expect(document.body.classList.contains("light-mode")).toBe(false);
  });

  it("sets body class to light-mode when [data-bs-theme] is not dark", async () => {
    document.documentElement.removeAttribute("data-bs-theme");
    await loadApiDocs();

    expect(document.body.classList.contains("light-mode")).toBe(true);
    expect(document.body.classList.contains("dark-mode")).toBe(false);
  });

  it("toggles body class when [data-bs-theme] changes", async () => {
    document.documentElement.setAttribute("data-bs-theme", "light");
    await loadApiDocs();

    expect(document.body.classList.contains("light-mode")).toBe(true);

    // Simulate theme toggle
    document.documentElement.setAttribute("data-bs-theme", "dark");
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(document.body.classList.contains("dark-mode")).toBe(true);
    expect(document.body.classList.contains("light-mode")).toBe(false);
  });

  it("does not hardcode darkMode: true", async () => {
    document.documentElement.setAttribute("data-bs-theme", "light");
    await loadApiDocs();

    const config = createApiReferenceMock.mock.calls[0][1];
    expect(config.darkMode).not.toBe(true);
  });

  it("hides Scalar's own dark mode toggle", async () => {
    await loadApiDocs();

    const config = createApiReferenceMock.mock.calls[0][1];
    expect(config.hideDarkModeToggle).toBe(true);
  });

  it("does not pass customCss in config (mappings are in HAML template)", async () => {
    await loadApiDocs();

    const config = createApiReferenceMock.mock.calls[0][1];
    expect(config.customCss).toBeUndefined();
  });
});
