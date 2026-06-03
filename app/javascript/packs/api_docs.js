// Initializes Scalar API Reference viewer on the /api/docs page.
// Uses customFetch for same-origin requests with session cookies,
// and onBeforeRequest to inject the Rails CSRF token.
document.addEventListener("DOMContentLoaded", function () {
  if (typeof Scalar === "undefined" || !document.getElementById("scalar-docs")) return;

  Scalar.createApiReference("#scalar-docs", {
    url: "/api/docs/openapi.yaml",
    theme: "kepler",
    darkMode: true,
    layout: "modern",
    showSidebar: true,
    searchHotKey: "k",
    hideTestRequestButton: false,
    authentication: {
      preferredSecurityScheme: "cookieAuth",
    },
    // Direct fetch with cookies — bypasses Scalar's sandboxed iframe proxy.
    // Session cookie is forwarded automatically (same-origin + credentials).
    customFetch: function (input, init) {
      return window.fetch(input, Object.assign({}, init, { credentials: "include" }));
    },
    // Inject Rails CSRF token on every mutation request.
    onBeforeRequest: function (ref) {
      var meta = document.querySelector('meta[name="csrf-token"]');
      if (meta) {
        ref.requestBuilder.headers.set("X-CSRF-Token", meta.content);
      }
    },
  });
});
