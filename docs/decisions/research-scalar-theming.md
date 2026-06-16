# Research: Scalar API Docs — Dark Mode + Vulcan Design System Integration

**Date:** 2026-06-07
**Card:** v2-ei3
**Sources:** Scalar docs (Context7 /scalar/scalar), Scalar GitHub documentation/themes.md,
documentation/configuration.md, documentation/integrations/html-js.md

## Findings

### 1. Dark Mode Toggle — `updateConfiguration()` + `forceDarkModeState`

Scalar's `createApiReference()` returns an app object with `updateConfiguration()`:

```javascript
const app = Scalar.createApiReference('#scalar-docs', { ... })

// Later, when user toggles theme:
app.updateConfiguration({ forceDarkModeState: 'dark' })  // or 'light'
```

`forceDarkModeState` overrides Scalar's internal color mode completely.
Type: `'dark' | 'light'`. Takes effect immediately — no destroy/recreate needed.

**Implementation:** Store the app reference, listen for Vulcan's theme change event,
call `updateConfiguration()`.

### 2. Initial State — Read from `[data-bs-theme]`

```javascript
const isDark = document.documentElement.getAttribute('data-bs-theme') === 'dark'
const app = Scalar.createApiReference('#scalar-docs', {
  darkMode: isDark,       // initial state
  // ...
})
```

No more hardcoded `darkMode: true`.

### 3. CSS Variable Mapping — `customCss` Option

Scalar exposes CSS custom properties that can be overridden. The `customCss` config
option injects CSS directly. Scalar uses `.light-mode` and `.dark-mode` class selectors.

**Scalar variables → Vulcan variable mapping:**

```
Scalar Variable            Vulcan Variable              Purpose
─────────────────────────  ───────────────────────────  ─────────────────────
--scalar-color-1           --vulcan-body-color          Primary text
--scalar-color-2           --vulcan-secondary-color     Secondary text (75%)
--scalar-color-3           (vulcan-secondary @ 50%)     Tertiary text
--scalar-color-accent      --vulcan-primary             Brand/accent color
--scalar-background-1      --vulcan-body-bg             Page background
--scalar-background-2      --vulcan-secondary-bg        Elevated surfaces
--scalar-background-3      --vulcan-tertiary-bg         Inset/recessed
--scalar-background-accent --vulcan-primary-tint        Accent tint
--scalar-border-color      --vulcan-border-color        Borders
--scalar-font              (inherit from body)          Typography
```

**Implementation via `customCss`:**

```javascript
Scalar.createApiReference('#scalar-docs', {
  customCss: `
    .light-mode, .dark-mode {
      --scalar-color-1: var(--vulcan-body-color);
      --scalar-color-2: var(--vulcan-secondary-color);
      --scalar-color-accent: var(--vulcan-primary);
      --scalar-background-1: var(--vulcan-body-bg);
      --scalar-background-2: var(--vulcan-secondary-bg);
      --scalar-background-3: var(--vulcan-tertiary-bg);
      --scalar-background-accent: var(--vulcan-primary-tint);
      --scalar-border-color: var(--vulcan-border-color);
    }
  `,
  // ...
})
```

**Why this works:** Scalar's `.light-mode` / `.dark-mode` classes are applied to the
Scalar container. The `var(--vulcan-*)` references resolve against the document root's
`:root` / `[data-bs-theme=dark]` blocks — which Vulcan already switches when the user
toggles. So Scalar inherits the correct values automatically per theme.

**Why `customCss` not a separate stylesheet:** The CSS must be injected INTO Scalar's
scope. An external stylesheet on the page would work too (Scalar doesn't use shadow DOM),
but `customCss` keeps it self-contained in the config — one file to maintain.

### 4. Scalar's Own Toggle — Hide It

Scalar renders its own light/dark toggle button in the sidebar footer. Since Vulcan
controls the theme globally, we should hide Scalar's toggle to avoid confusion:

```css
/* In customCss */
button[aria-label="Set light mode"],
button[aria-label="Set dark mode"] {
  display: none !important;
}
```

Or check if Scalar has a config option to disable it. The `colorScheme.showToggle: false`
is for Scalar's docs platform, not the CDN embed. May need the CSS approach.

### 5. REJECTED: updateConfiguration({ forceDarkModeState })

During implementation, `updateConfiguration()` caused Scalar's internal theme state to
reset, overwriting custom CSS variable mappings with Scalar's CDN defaults. The body
class approach (§5b below) avoids this by not triggering Scalar's internal state machine.

### 5b. ADOPTED: Body class toggle + document-level `<style>` tag

```javascript
document.addEventListener("DOMContentLoaded", function () {
  if (typeof Scalar === "undefined" || !document.getElementById("scalar-docs")) return;

  var isDark = document.documentElement.getAttribute("data-bs-theme") === "dark";

  var app = Scalar.createApiReference("#scalar-docs", {
    url: "/api/docs/openapi.yaml",
    theme: "kepler",
    darkMode: isDark,
    forceDarkModeState: isDark ? "dark" : "light",
    layout: "modern",
    showSidebar: true,
    searchHotKey: "k",
    hideTestRequestButton: false,
    authentication: {
      preferredSecurityScheme: "cookieAuth",
    },
    customCss: [
      ".light-mode, .dark-mode {",
      "  --scalar-color-1: var(--vulcan-body-color);",
      "  --scalar-color-2: var(--vulcan-secondary-color);",
      "  --scalar-color-accent: var(--vulcan-primary);",
      "  --scalar-background-1: var(--vulcan-body-bg);",
      "  --scalar-background-2: var(--vulcan-secondary-bg);",
      "  --scalar-background-3: var(--vulcan-tertiary-bg);",
      "  --scalar-background-accent: var(--vulcan-primary-tint);",
      "  --scalar-border-color: var(--vulcan-border-color);",
      "}",
    ].join("\n"),
    customFetch: function (input, init) {
      return window.fetch(input, Object.assign({}, init, { credentials: "include" }));
    },
    onBeforeRequest: function (ref) {
      var meta = document.querySelector('meta[name="csrf-token"]');
      if (meta) {
        ref.requestBuilder.headers.set("X-CSRF-Token", meta.content);
      }
    },
  });

  // Sync with Vulcan theme toggle
  var observer = new MutationObserver(function (mutations) {
    mutations.forEach(function (mutation) {
      if (mutation.attributeName === "data-bs-theme") {
        var newTheme = document.documentElement.getAttribute("data-bs-theme");
        app.updateConfiguration({
          forceDarkModeState: newTheme === "dark" ? "dark" : "light",
        });
      }
    });
  });
  observer.observe(document.documentElement, { attributes: true, attributeFilter: ["data-bs-theme"] });
});
```

### 6. Key Design Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Theme sync mechanism | MutationObserver on `[data-bs-theme]` | Framework-agnostic, works with any toggle implementation |
| Color mapping | `var(--vulcan-*)` in customCss | Single source of truth — Vulcan variables auto-switch per theme |
| Scalar's own toggle | Hide via CSS | Vulcan's navbar toggle is the single control |
| Initial state | Read `[data-bs-theme]` attribute | Matches what user sees on page load |
| Runtime update | `updateConfiguration({ forceDarkModeState })` | Scalar's documented API — no destroy/recreate |

### 7. Risk Assessment

**Low risk:**
- `customCss` is a documented config option — not a hack
- `updateConfiguration()` is the documented runtime update API
- `var(--vulcan-*)` references are stable (design system contract)
- MutationObserver is standard DOM API
- No shadow DOM isolation issues (Scalar renders in normal DOM)

**Edge case:** If `--vulcan-*` variables aren't defined (e.g., on a non-Vulcan page),
Scalar falls back to its built-in theme values. Safe degradation.
