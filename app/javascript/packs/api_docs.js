// Initializes Scalar API Reference viewer on the /api/docs page.
// Theme sync: Vulcan's [data-bs-theme] controls Scalar's .dark-mode/.light-mode
// body class. Variable mappings are in the HAML template <style> tag (document
// cascade beats Scalar's CDN theme defaults).
document.addEventListener("DOMContentLoaded", function () {
  if (typeof Scalar === "undefined" || !document.getElementById("scalar-docs")) return;

  var isDark = document.documentElement.getAttribute("data-bs-theme") === "dark";

  // Scalar reads .dark-mode / .light-mode from <body>. Set it before init.
  syncScalarThemeClass(isDark);

  Scalar.createApiReference("#scalar-docs", {
    sources: [
      {
        url: "/api/docs/openapi.yaml",
      },
    ],
    theme: "kepler",
    darkMode: isDark,
    layout: "modern",
    showSidebar: true,
    searchHotKey: "k",
    hideTestRequestButton: false,
    hideDarkModeToggle: true,
    authentication: {
      preferredSecurityScheme: "cookieAuth",
    },
    // Direct fetch with cookies — bypasses Scalar's sandboxed iframe proxy.
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

  // Watch Vulcan's theme toggle and sync the body class for Scalar.
  var observer = new MutationObserver(function (mutations) {
    mutations.forEach(function (mutation) {
      if (mutation.attributeName === "data-bs-theme") {
        var dark = document.documentElement.getAttribute("data-bs-theme") === "dark";
        syncScalarThemeClass(dark);
      }
    });
  });
  observer.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ["data-bs-theme"],
  });
});

function syncScalarThemeClass(isDark) {
  document.body.classList.toggle("dark-mode", isDark);
  document.body.classList.toggle("light-mode", !isDark);
}
