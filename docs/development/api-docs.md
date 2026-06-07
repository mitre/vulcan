# API Documentation (Scalar)

Vulcan serves interactive API documentation at `/api/docs` using [Scalar](https://scalar.com),
a modern OpenAPI viewer.

## Architecture

```
app/views/api_docs/show.html.haml     # Page template + CSS variable mappings
app/javascript/packs/api_docs.js      # Scalar initialization + theme sync
app/controllers/api_docs_controller.rb # Serves page + OpenAPI spec YAML
doc/openapi.yaml                       # Bundled OpenAPI spec (generated)
```

## Theme Integration

Scalar's colors are mapped to Vulcan's design system variables so the API docs
match the rest of the application in both light and dark mode.

### How It Works

1. **CSS variable mapping** — The HAML template contains a `<style>` block that maps
   Scalar's `--scalar-*` variables to Vulcan's `--vulcan-*` variables using `var()` references.
   Since Vulcan's root variables auto-switch when `[data-bs-theme]` changes, Scalar
   inherits the correct colors per theme automatically.

2. **Body class sync** — Scalar reads `.dark-mode` / `.light-mode` from `<body>`.
   A `MutationObserver` in `api_docs.js` watches `[data-bs-theme]` on `<html>` and
   toggles the body class to match. No `updateConfiguration()` call needed — direct
   class manipulation avoids Scalar's internal state reset that would overwrite custom colors.

3. **Scalar's own toggle hidden** — `hideDarkModeToggle: true` in the config. Vulcan's
   navbar toggle is the single control for theme switching app-wide.

### Variable Mapping

| Scalar Variable              | Vulcan Variable              | Purpose            |
|------------------------------|------------------------------|---------------------|
| `--scalar-color-1`           | `--vulcan-body-color`        | Primary text        |
| `--scalar-color-2`           | `--vulcan-secondary-color`   | Secondary text      |
| `--scalar-color-accent`      | `--vulcan-primary`           | Brand/accent color  |
| `--scalar-background-1`      | `--vulcan-body-bg`           | Page background     |
| `--scalar-background-2`      | `--vulcan-secondary-bg`      | Elevated surfaces   |
| `--scalar-background-3`      | `--vulcan-tertiary-bg`       | Inset/recessed      |
| `--scalar-background-accent` | `--vulcan-primary-tint`      | Accent tint         |
| `--scalar-border-color`      | `--vulcan-border-color`      | Borders             |

### Why `<style>` Tag Instead of `customCss` Config

Scalar's `customCss` config option injects CSS, but `updateConfiguration()` can reset it
when the internal theme state changes. A `<style>` tag in the HAML template is part of the
document cascade — it loads after Scalar's CDN stylesheet and always wins by cascade order.
The `!important` declarations ensure our mappings override Scalar's theme preset defaults
regardless of specificity.

## Configuration

All Scalar configuration is in `app/javascript/packs/api_docs.js`:

- **`theme: "kepler"`** — Scalar's default dark theme preset (our CSS overrides replace its colors)
- **`darkMode`** — Initial state read from `[data-bs-theme]`
- **`hideDarkModeToggle: true`** — Scalar's own toggle is hidden
- **`searchHotKey: "k"`** — Cmd+K opens Scalar's search
- **`customFetch`** — Uses `window.fetch` with `credentials: "include"` for session cookies
- **`onBeforeRequest`** — Injects the Rails CSRF token on mutation requests

## Authentication

Scalar uses session cookie authentication (same as the rest of Vulcan). The `customFetch`
function bypasses Scalar's sandboxed iframe proxy and sends requests directly with
`credentials: "include"`, so the session cookie is forwarded automatically.

The CSRF token is injected via `onBeforeRequest` from the `<meta name="csrf-token">` tag.

## Updating the Spec

The spec served at `/api/docs/openapi.yaml` is `doc/openapi.yaml` — the bundled output.
After editing any file in `doc/openapi/`, regenerate and commit:

```bash
yarn openapi:bundle && yarn openapi:lint
git add doc/openapi.yaml
```

A lefthook pre-commit hook (`openapi-bundle-check`) enforces this — commits that touch
`doc/openapi/**` but have a stale `doc/openapi.yaml` will be rejected.
