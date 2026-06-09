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
        title: "Vulcan API",
        url: "https://registry.scalar.com/@mitre/apis/vulcan/latest?format=json",
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
    // Include cookies only for same-origin API requests ("Try it" button).
    // Cross-origin fetches (registry spec load) must NOT send credentials
    // because the registry responds with Access-Control-Allow-Origin: *.
    customFetch: function (input, init) {
      var url = typeof input === "string" ? input : input.url || "";
      var sameOrigin = url.startsWith("/") || url.startsWith(window.location.origin);
      var opts = Object.assign({}, init);
      if (sameOrigin) opts.credentials = "include";
      return window.fetch(input, opts);
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
